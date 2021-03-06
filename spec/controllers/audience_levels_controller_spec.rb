require 'spec/spec_helper'
 
describe AudienceLevelsController do
  fixtures :all
  integrate_views

  before(:each) do
    Factory(:audience_level)
  end

  it "index action should render index template" do
    get :index
    response.should render_template(:index)
  end  

end
