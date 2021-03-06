require 'spec/spec_helper'
 
describe ReviewDecisionsController do
  integrate_views

  it_should_require_login_for_actions :new, :create, :edit, :update

  before(:each) do
    @session = Factory(:session)
    @organizer = Factory(:organizer, :track => @session.track)
    activate_authlogic
    UserSession.create(@organizer.user)
  end
  
  it "new action should render new template" do
    get :new, :session_id => Session.first
    response.should render_template(:new)
    assigns[:review_decision].organizer.should == @organizer.user
  end

  it "create action should render new template when model is invalid" do
    # +stubs(:valid?).returns(false)+ doesn't work here because
    # inherited_resources does +obj.errors.empty?+ to determine
    # if validation failed
    post :create, :review_decision => {}, :session_id => Session.first
    response.should render_template(:new)
  end
  
  it "create action should redirect when model is valid" do
    ReviewDecision.any_instance.stubs(:valid?).returns(true)
    post :create, :session_id => Session.first
    response.should redirect_to(organizer_sessions_url)
  end
  
  context "existing review decision" do
    before(:each) do
      @decision = Factory(:review_decision, :session => @session, :organizer => @organizer.user)
    end
    
    it "edit action should render edit template" do
      get :edit, :session_id => @session.id, :id => @decision.id
      response.should render_template(:edit)
      assigns[:review_decision].organizer.should == @organizer.user
    end
  
    it "update action should render edit template when model is invalid" do
      # +stubs(:valid?).returns(false)+ doesn't work here because
      # inherited_resources does +obj.errors.empty?+ to determine
      # if validation failed
      post :update, :review_decision => {:note_to_authors => nil}, :session_id => @session.id, :id => @decision.id
      response.should render_template(:edit)
    end
  
    it "update action should redirect when model is valid" do
      ReviewDecision.any_instance.stubs(:valid?).returns(true)
      post :update, :session_id => @session.id, :id => @decision.id
      response.should redirect_to(organizer_sessions_url)
    end
  end
end
