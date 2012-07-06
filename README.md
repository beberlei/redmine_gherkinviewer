# Redmine Plugin: Gherkin Viewer

Renders Gherkin (Cucumber, Behat, ..) feature files from the source code-repository into the Redmine project.
This acts as an automatic publishing mechanism of the "living documentation" of a project.

![Behat Example Screen](https://github.com/beberlei/redmine_gherkinviewer/tree/master/screen_behat.png) 

## Installation

1. Change to "vendor/plugins"
2. Checkout code `git clone git://github.com/beberlei/redmine_gherkinviewer.git`
3. Back to project root
4. `bundle install --without development`
5. Create a project custom variable named `gherkin_features`

This plugin does not need a database change!

## Usage

1. Switch to project where you want to enable this, activate Gherkinviewer.
2. Enable "Gherkinviewer" in all user roles that should see the features.
3. Edit Project details and change `gherkin_features` variable to contain a comma-seperated list of feature folders. These feature folders will be searched recursively.

## TODO

* Make HTML output nicer
* Support multiple repositories per project

## Author

Benjamin Eberlei <kontakt@beberlei.de>

## LICENSE

Licensed under the GPL.

