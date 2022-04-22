# Vanity

[![Gem Version](https://badge.fury.io/rb/vanity.svg)](https://rubygems.org/gems/vanity)
[![Test Status](https://github.com/assaf/vanity/workflows/Test/badge.svg)](https://github.com/assaf/vanity/actions)
[![Ruby Toolbox](https://img.shields.io/badge/dynamic/json?color=blue&label=Ruby%20Toolbox&query=%24.projects%5B0%5D.score&url=https%3A%2F%2Fwww.ruby-toolbox.com%2Fapi%2Fprojects%2Fcompare%2Fvanity&logo=data:image/svg+xml;base64,PHN2ZyBhcmlhLWhpZGRlbj0idHJ1ZSIgZm9jdXNhYmxlPSJmYWxzZSIgZGF0YS1wcmVmaXg9ImZhcyIgZGF0YS1pY29uPSJmbGFzayIgY2xhc3M9InN2Zy1pbmxpbmUtLWZhIGZhLWZsYXNrIGZhLXctMTQiIHJvbGU9ImltZyIgeG1sbnM9Imh0dHA6Ly93d3cudzMub3JnLzIwMDAvc3ZnIiB2aWV3Qm94PSIwIDAgNDQ4IDUxMiI+PHBhdGggZmlsbD0id2hpdGUiIGQ9Ik00MzcuMiA0MDMuNUwzMjAgMjE1VjY0aDhjMTMuMyAwIDI0LTEwLjcgMjQtMjRWMjRjMC0xMy4zLTEwLjctMjQtMjQtMjRIMTIwYy0xMy4zIDAtMjQgMTAuNy0yNCAyNHYxNmMwIDEzLjMgMTAuNyAyNCAyNCAyNGg4djE1MUwxMC44IDQwMy41Qy0xOC41IDQ1MC42IDE1LjMgNTEyIDcwLjkgNTEyaDMwNi4yYzU1LjcgMCA4OS40LTYxLjUgNjAuMS0xMDguNXpNMTM3LjkgMzIwbDQ4LjItNzcuNmMzLjctNS4yIDUuOC0xMS42IDUuOC0xOC40VjY0aDY0djE2MGMwIDYuOSAyLjIgMTMuMiA1LjggMTguNGw0OC4yIDc3LjZoLTE3MnoiPjwvcGF0aD48L3N2Zz4=)](https://www.ruby-toolbox.com/projects/vanity)

Vanity is an A/B testing framework for Rails that is datastore agnostic.

*   All about Vanity: http://vanity.labnotes.org
*   On Github: http://github.com/assaf/vanity

[![Dashboard](doc/images/sidebar_test.png)](http://github.com/assaf/vanity)

<!-- toc -->

- [Installation](#installation)
- [Setup](#setup)
  * [Datastore](#datastore)
    + [Redis Setup](#redis-setup)
    + [MongoDB Setup](#mongodb-setup)
    + [SQL Database Setup](#sql-database-setup)
    + [Forking servers and reconnecting](#forking-servers-and-reconnecting)
  * [Initialization](#initialization)
  * [User identification](#user-identification)
    + [Rails](#rails)
    + [Other](#other)
  * [Define a A/B test](#define-a-ab-test)
  * [Present the different options to your users](#present-the-different-options-to-your-users)
  * [Measure conversion](#measure-conversion)
  * [Check the report](#check-the-report)
    + [Rails report dashboard](#rails-report-dashboard)
- [Registering participants with Javascript](#registering-participants-with-javascript)
- [Compatibility](#compatibility)
- [Testing](#testing)
- [Updating documentation](#updating-documentation)
- [Contributing](#contributing)
- [Credits/License](#creditslicense)

<!-- tocstop -->

## Installation

Add to your Gemfile:

```ruby
gem "vanity"
```

(For support for older versions of Rails and Ruby 1.8, please see the [1.9.x
branch](https://github.com/assaf/vanity/tree/1-9-stable).)

## Setup

### Datastore

Choose a datastore that best fits your needs and preferences for storing
experiment results. Choose one of: Redis, MongoDB or an SQL database. While
Redis is usually faster, it may add additional complexity to your stack.
Datastores should be configured using a `config/vanity.yml`.

#### Redis Setup

Add to your Gemfile:

```ruby
gem "redis", ">= 3.2"
gem "redis-namespace", ">= 1.1.0"
```

By default Vanity is configured to use Redis on localhost port 6379 with
database 0.

A sample `config/vanity.yml` might look like:

```yaml
test:
  collecting: false
production:
  adapter: redis
  url: redis://<%= ENV["REDIS_USER"] %>:<%= ENV["REDIS_PASSWORD"] %>@<%= ENV["REDIS_HOST"] %>:<%= ENV["REDIS_PORT"] %>/0
```

If you want to use your test environment with RSpec you will need to add an
adapter to test:

```yaml
test:
  adapter: redis
  collecting: false
```

To re-use an existing redis connection, you can call `Vanity.connect!` explicitly, for example:

```ruby
Vanity.connect!(
  adapter: :redis,
  redis: $redis
)
```

#### MongoDB Setup

Add to your Gemfile:

```ruby
gem "mongo", "~> 2.0" # For Mongo 1.x support see Vanity versions 2.1 and below.
```

A sample `config/vanity.yml` might look like:

```yaml
development:
  adapter: mongodb
  database: analytics
test:
  collecting: false
production:
  adapter: mongodb
  database: analytics
```

#### SQL Database Setup

Vanity supports multiple SQL stores (like MySQL, MariaDB, Postgres, Sqlite,
etc.) using ActiveRecord, which is built into Rails. If you're using
DataMapper, Sequel or another persistence framework, add to your Gemfile:

```ruby
    gem "active_record"
```

A sample `config/vanity.yml` might look like:

```yaml
development:
  adapter: active_record
  active_record_adapter: sqlite3
  database: db/development.sqlite3
test:
  adapter: active_record
  active_record_adapter: default
  collecting: false
production:
  adapter: active_record
  active_record_adapter: postgresql
  <% uri = URI.parse(ENV['DATABASE_URL']) %>
  host:     <%= uri.host %>
  username: <%= uri.user%>
  password: <%= uri.password %>
  port:     <%= uri.port %>
  database: <%= uri.path.sub('/', '') %>
```

If you're going to store data in the database, run the generator and
migrations to create the database schema:

```sh
$ rails generate vanity
$ rake db:migrate
```

#### Forking servers and reconnecting

If you're using a forking server (like Passenger or Unicorn), you should
reconnect after a new worker is created:

```ruby
# unicorn.rb
after_fork do |server, worker|
  defined?(Vanity) && Vanity.reconnect!
end

# an initializer
if defined?(PhusionPassenger)
  PhusionPassenger.on_event(:starting_worker_process) do |forked|
    # We're in smart spawning mode.
    if forked
      defined?(Vanity) && Vanity.reconnect!
    end
  end
end
```

If you're using explicit options with `Vanity.connect!`, you should call `disconnect!` first, for example:

```ruby
Vanity.disconnect!
Vanity.connect!(
  adapter: 'redis',
  redis: $redis
)
```

### Initialization

If you're using Rails, this is done automagically. Otherwise, some manual setup is required, for example on an app's booting:

```
$redis = Redis.new # or from elsewhere
Vanity.configure do |config|
  # ... any config
end
Vanity.connect!(
  adapter: :redis,
  redis: $redis
)
Vanity.load!
```

### User identification

#### Rails

Turn Vanity on, and pass a reference to a method that identifies a user. For
example:

```ruby
class ApplicationController < ActionController::Base
  use_vanity :current_user
end
```

For more information, please see the [identity
documentation](http://vanity.labnotes.org/identity.html).

#### Other

Vanity pulls the identity from a "context" object that responds to `vanity_identity`, so we need to define a `Vanity.context` (this is how the [ActionMailer integration](https://github.com/assaf/vanity/blob/master/lib/vanity/frameworks/rails.rb#L107-L133) works):

```
class AVanityContext
  def vanity_identity
    "123"
  end
end

Vanity.context = AVanityContext.new() # Any object that responds to `#vanity_identity`
```

If you're using plain ruby objects, you could also alias something in your identity model to respond similarly and then set that as the vanity context:
```
class User
  alias_method :vanity_identity, :id
end
```

### Define a A/B test

This experiment goes in the file `experiments/price_options.rb`:

```ruby
ab_test "Price options" do
  description "Mirror, mirror on the wall, who's the better price of all?"
  alternatives 19, 25, 29
  metrics :signups
end
```

If the experiment uses a metric as above ("signups"), there needs to be a
corresponding ruby file for that metric, `experiments/metrics/signups.rb`.

```ruby
metric "Signup (Activation)" do
  description "Measures how many people signed up for our awesome service."
end
```

### Present the different options to your users

In Rails' templates, this is straightforward:

```erb
<h2>Get started for only $<%= ab_test :price_options %> a month!</h2>
```

Outside of templates:

```
Vanity.ab_test(:invite_subject)
```

### Measure conversion

Conversions are created via the `Vanity.track!` method. A user should already be added to an experiment, via `ab_test` before this is called - otherwise, the conversion will be tracked, but the user will not be added to the experiment.

For example, in Rails:

```ruby
class SignupController < ApplicationController
  def signup
    @account = Account.new(params[:account])
    if @account.save
      Vanity.track!(:signups)
      redirect_to @acccount
    else
      render action: :offer
    end
  end
end
```

Outside of an Rails controller, for example in a Rack handler:

```
identity_object = Identity.new(env['rack.session'])
Vanity.track!(:click, {
  # can be any object that responds to `to_s` with a string
  # that contains the unique identifier or the string identifier itself
  :identity=>identity_object,
  :values=>[1] # optional
})
```

### Check the report

```sh
vanity report --output vanity.html
```

#### Rails report dashboard

To view metrics and experiment results with the dashboard in Rails 3 & Rails
4:

```sh
rails generate controller Vanity --helper=false
```

In `config/routes.rb`, add:

```ruby
get '/vanity' =>'vanity#index'
get '/vanity/participant/:id' => 'vanity#participant'
post '/vanity/complete'
post '/vanity/chooses'
post '/vanity/reset'
post '/vanity/enable'
post '/vanity/disable'
post '/vanity/add_participant'
get '/vanity/image'
```

The controller should look like:

```ruby
class VanityController < ApplicationController
  include Vanity::Rails::Dashboard
  layout false  # exclude this if you want to use your application layout
end
```

## Registering participants with Javascript

If robots or spiders make up a significant portion of your sites traffic they
can affect your conversion rate. Vanity can optionally add participants to the
experiments using asynchronous javascript callbacks, which will keep many
robots out. For those robots that do execute Javascript and are well-behaved
(like Googlebot), Vanity filters out requests based on their user-agent
string.

In Rails, add the following to `application.rb`:

```ruby
Vanity.configure do |config|
  config.use_js = true

  # Optionally configure the add_participant route that is added with Vanity::Rails::Dashboard,
  # make sure that this action does not require authentication
  # config.add_participant_route = '/vanity/add_participant'
end
```

Then add `<%= vanity_js %>` to any page that calls an A/B test **after calling
`ab_test`**. `vanity_js` needs to be included after your call to ab_test so
that it knows which version of the experiment the participant is a member of.
The helper will render nothing if the there are no ab_tests running on the
current page, so adding `vanity_js` to the bottom of your layouts is a good
option. Keep in mind that if you set `use_js` and don't include `vanity_js` in
your view no participants will be recorded.

## Compatibility

Here's what's tested and known to work:

    Rails: 5.2+
    Ruby: 2.5+
    JRuby: 9.1+
    Persistence: Redis (redis-rb >= 3.2.1), Mongo, ActiveRecord

## Testing

For view tests/specs or integration testing, it's handy to set the outcome of
an experiment. This may be done using the `chooses` method. For example:

```ruby
Vanity.playground.experiment(:price_options).chooses(19)
```

See [the docs on testing](http://vanity.labnotes.org/ab_testing.html#test) for more.

## Updating documentation

Documenation is written in the textile format in the [docs](docs/) directory,
and is hosted on Github Pages. To update the docs commit changes to the master
branch in this repository, then:

```sh
bundle exec rake docs # output HTML files into html/
git checkout gh-pages
mv html/* . # Move generated html to the top of the repo
git commit # Add, commit and push any changes!
```

Go ahead and target a pull request against the `gh-pages` branch.

## Contributing

*   Fork the project
*   Please use a feature branch to make your changes, it's easier to test them
    that way
*   To set up the test suite run `bundle`, then run `appraisal install` to
    prepare the test suite to run against multiple versions of Rails
*   Fix, patch, enhance, document, improve, sprinkle pixie dust
*   Tests. Please. Run `appraisal rake test`, of if you can, `rake test:all`.
    (This project uses Github Actions where the test suite is run against multiple
    versions of ruby, rails and backends.)
*   Send a pull request on GitHub


## Credits/License

Original code, copyright of Assaf Arkin, released under the MIT license.

Documentation available under the Creative Commons Attribution license.

For full list of credits and licenses:
http://vanity.labnotes.org/credits.html.
