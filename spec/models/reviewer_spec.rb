require 'spec/spec_helper'

describe Reviewer do
  before(:each) do
    EmailNotifications.stubs(:deliver_reviewer_invitation)
  end
  
  context "protect from mass assignment" do
    should_allow_mass_assignment_of :user_id
    should_allow_mass_assignment_of :user_username
    should_allow_mass_assignment_of :preferences_attributes
    should_allow_mass_assignment_of :reviewer_agreement
    should_allow_mass_assignment_of :state_event
  
    should_not_allow_mass_assignment_of :evil_attr
  end
  
  it_should_trim_attributes Reviewer, :user_username

  context "validations" do
    before { Factory(:reviewer) }
    should_validate_presence_of :user_username
    should_validate_uniqueness_of :user_id
    
    it "should validate existence of user" do
      reviewer = Factory.build(:reviewer)
      reviewer.should be_valid
      reviewer.user_id = 0
      reviewer.should_not be_valid
      reviewer.errors.on(:user).should == "não existe"
    end
    
    it "should validate that at least 1 preference was accepted" do
      reviewer = Factory(:reviewer)
      reviewer.preferences.build(:accepted => false)
      reviewer.accept.should be_false
      reviewer.errors.on(:base).should == "pelo menos uma trilha deve ser aceita"
    end

    it "should validate that reviewer agreement was accepted" do
      reviewer = Factory(:reviewer, :reviewer_agreement => false)
      reviewer.preferences.build(:accepted => true, :track_id => 1, :audience_level_id => 1)
      reviewer.accept.should be_false
      reviewer.errors.on(:reviewer_agreement).should == "deve ser aceito"
    end
    
    it "should copy user errors to user_username" do
      reviewer = Factory(:reviewer)
      new_reviewer = Factory.build(:reviewer, :user => reviewer.user)
      new_reviewer.should_not be_valid
      new_reviewer.errors.on(:user_username).should == "já está em uso"
    end

    context "user" do
      before(:each) do
        @reviewer = Factory(:reviewer)
      end
      
      it "should be a valid user" do
        @reviewer.user_username = 'invalid_username'
        @reviewer.should_not be_valid
        @reviewer.errors.on(:user_username).should include("não existe")
      end
    end      
  end
  
  context "associations" do
    should_belong_to :user
    should_have_many :preferences
    should_have_many :accepted_preferences, :class_name => 'Preference', :conditions => ['preferences.accepted = ?', true]
    
    should_accept_nested_attributes_for :preferences

    context "user association by username" do
      before(:each) do
        @reviewer = Factory(:reviewer)
        @user = Factory(:user)
      end
      
      it "should set by username" do
        @reviewer.user_username = @user.username
        @reviewer.user.should == @user
      end
    
      it "should not set if username is nil" do
        @reviewer.user_username = nil
        @reviewer.user.should be_nil
      end

      it "should not set if username is empty" do
        @reviewer.user_username = ""
        @reviewer.user.should be_nil
      end

      it "should not set if username is only spaces" do
        @reviewer.user_username = "  "
        @reviewer.user.should be_nil
      end
      
      it "should provide username from association" do
        @reviewer.user_username = @user.username
        @reviewer.user_username.should == @user.username
      end
    end
  end
  
  context "state machine" do
    before(:each) do
      @reviewer = Factory.build(:reviewer)
    end
    
    context "State: created" do
      it "should be the initial state" do
        @reviewer.should be_created
      end
      
      it "should allow invite" do
        @reviewer.invite.should be_true
        @reviewer.should_not be_created
        @reviewer.should be_invited
      end

      it "should not allow accept" do
        @reviewer.accept.should be_false
      end

      it "should not allow reject" do
        @reviewer.reject.should be_false
      end
    end
    
    context "Event: invite" do
      it "should send invitation email" do
        EmailNotifications.expects(:deliver_reviewer_invitation).with(@reviewer)
        @reviewer.invite
      end
    end
    
    context "State: invited" do
      before(:each) do
        @reviewer.invite
        @reviewer.should be_invited
      end
      
      it "should allow inviting again" do
        @reviewer.invite.should be_true
        @reviewer.should be_invited
      end
      
      it "should allow accepting" do
        @reviewer.preferences.build(:accepted => true, :track_id => 1, :audience_level_id => 1)
        @reviewer.accept.should be_true
        @reviewer.should_not be_invited
        @reviewer.should be_accepted
      end

      it "should allow rejecting" do
        @reviewer.reject.should be_true
        @reviewer.should_not be_invited
        @reviewer.should be_rejected
      end
    end

    context "State: accepted" do
      before(:each) do
        @reviewer.invite
        @reviewer.preferences.build(:accepted => true, :track_id => 1, :audience_level_id => 1)
        @reviewer.accept
        @reviewer.should be_accepted
      end
      
      it "should not allow invite" do
        @reviewer.invite.should be_false
      end
      
      it "should not allow accepting" do
        @reviewer.accept.should be_false
      end

      it "should not allow rejecting" do
        @reviewer.reject.should be_false
      end
    end

    context "State: rejected" do
      before(:each) do
        @reviewer.invite
        @reviewer.reject
        @reviewer.should be_rejected
      end
      
      it "should not allow invite" do
        @reviewer.invite.should be_false
      end
      
      it "should not allow accepting" do
        @reviewer.accept.should be_false
      end

      it "should not allow rejecting" do
        @reviewer.reject.should be_false
      end
    end
  end
  
  context "callbacks" do
    it "should invite after created" do
      reviewer = Factory.build(:reviewer)
      reviewer.save
      reviewer.should be_invited
    end
    
    it "should not invite if validation failed" do
      reviewer = Factory.build(:reviewer, :user_id => nil)
      reviewer.save
      reviewer.should_not be_invited
    end
  end

  shared_examples_for "reviewer role" do
    it "should make given user reviewer role after invitation accepted" do
      reviewer = Factory(:reviewer, :user => @user)
      reviewer.invite
      @user.should_not be_reviewer
      reviewer.preferences.build(:accepted => true, :track_id => 1, :audience_level_id => 1)
      reviewer.accept
      @user.should be_reviewer
      @user.reload.should be_reviewer
    end
    
    it "should remove organizer role after destroyed" do
      reviewer = Factory(:reviewer, :user => @user)
      reviewer.invite
      reviewer.preferences.build(:accepted => true, :track_id => 1, :audience_level_id => 1)
      reviewer.accept
      @user.should be_reviewer
      reviewer.destroy
      @user.should_not be_reviewer
      @user.reload.should_not be_reviewer
    end
  end
  
  context "managing reviewer role for complete user" do
    before(:each) do
      @user = Factory(:user)
    end
    
    it_should_behave_like "reviewer role"
  end

  context "managing reviewer role for simple user" do
    before(:each) do
      @user = Factory(:simple_user)
    end
    
    it_should_behave_like "reviewer role"
  end
  
  context "checking if able to review a track" do
    before(:each) do
      @organizer = Factory(:organizer)
      @reviewer = Factory(:reviewer, :user => @organizer.user)
    end
    
    it "can review track when not organizer" do
      @reviewer.should be_can_review(Factory(:track))
    end
    
    it "can not review track when organizer" do
      @reviewer.should_not be_can_review(@organizer.track)
    end
  end
end
