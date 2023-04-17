# Callstacking::Rails
[![Build Status](https://github.com/callstacking/callstacking-rails/actions/workflows/ci.yml/badge.svg)](https://github.com/callstacking/callstacking-rails/actions/workflows/ci.yml)

Call Stacking is a rolling, checkpoint debugger for Rails.  It records all of the critical method calls within your app, along with their important context (param/argument/return/local variable values).  

You no longer need to debug with `binding.pry` or `puts` statements, as the entire callstack for a given request is captured.

Demo video:
[![Watch the video](https://user-images.githubusercontent.com/4600/190929740-fc68e18f-9572-41be-9719-cc6a8077e97f.png)](https://www.youtube.com/watch?v=NGqnwcNWv_k)

Class method calls are labeled.  Return values for those calls are denoted with ↳

Arguments for a method will be listed along with their calling values.

For method returns ↳, the final values of the local variables will be listed when you hover over the entry.

<img width="1695" alt="CleanShot 2022-09-17 at 21 10 32@2x" src="https://user-images.githubusercontent.com/4600/190882603-a99e9358-9754-4cbf-ac68-a41d53afe747.png">

Subsequent calls within a method are visibly nested.

Call Stacking is a Rails engine that you mount within your Rails app.

Here's a sample debugging sessions recorded from a Jumpstart Rails based app I've been working on.  This is a request for the main page ( https://smartk.id/ ).

![image](https://user-images.githubusercontent.com/4600/190882432-58092e38-7ee2-4138-b13a-f45ff2b09227.png)

Call Stacking Rails records all of the critical method calls within your app, along with their important context (param/argument/return/local variable values).

All in a rolling panel, so that you can debug your call chains from any point in the stack.

You'll never have to debug with `puts` statements ever again.

Calls are visibly nested so that it's easy to see which calls are issued from which parent methods.

## Installation
Add this line to your application's Gemfile:

```ruby
gem "callstacking-rails"
```

And then execute:
```bash
$ bundle
```

Add the following to your `ApplicationController`:

```
class ApplicationController < ActionController::Base
  include Callstacking::Rails::Helpers::InstrumentHelper

  around_action :callstacking_setup, if: -> { params[:debug] == '1' }
```


Register an account at callstacking.com
```bash
callstacking-rails register
```

Authenticate to your newly created account.

```bash
callstacking-rails setup
```
            
You're now ready to start tracing.

## CLI Setup
Usage:

> callstacking-rails register

Opens a browser window to register as a callstacking.com user.

> callstacking-rails setup

Interactively prompts you for your callstacking.com username/password.
Stores auth details in `~/.callstacking`.

You can have multiple environments.
The default is `development`.

The `development:` section in the `~/.callstacking` config contains your credentials.

By setting the RAILS_ENV environment you can maintain multiple settings.

Questions? Create an issue: https://github.com/callstacking/callstacking-rails/issues

## Tracing
To initiate a trace, append the `debug=1` param to the URL of the page you want to trace. As outlined in the `around_action` you setup above.

## Environment

You can provide the auth token via the `CALLSTACKING_AUTH_TOKEN` environment variable.

Your API token values can be viewed at https://callstacking.com/api_tokens

You can enable/disable tracing via the `CALLSTACKING_ENABLED` environment variable (false|true).

## Trace Output
For HTML requests, once your page has rendered, you will see a `💥` icon on the right hand side.

Click the icon and observe the full callstack context.

For headless API requests, visit https://callstacking.com/traces to view your traces.

## Tests
``
rake app:test:all
``

## License
The gem is available as open source under the terms of the [GPLv3 License](https://www.gnu.org/licenses/gpl-3.0.en.html).
