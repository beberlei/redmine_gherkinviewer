require 'redmine'

Redmine::Plugin.register :redmine_gherkinviewer do
  name 'Redmine Gherkin Viewer plugin'
  author 'Benjamin Eberlei'
  description 'Display Gherkin Features in your source-code  as living documentation in the project.'
  version '0.0.1'
  url 'http://example.com/path/to/plugin'
  author_url 'http://www.beberlei.de'

  project_module :gherkinviewer do
    permission :gherkinviewer, :features => :view
  end
  menu :project_menu, :gherkinviewer, { :controller => 'features', :action => 'view' }, :caption => 'Features', :after => :activity, :param => :project_id
end
