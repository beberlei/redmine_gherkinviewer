ActionController::Routing::Routes.draw do |map|
    map.features '/projects/:project_id/features', :controller => :features, :action => :view
end
