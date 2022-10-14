# Checkpoint::Rails

Checkpoint Rails is a rolling, checkpoint debugger for Rails.  It records all of the critical method calls within your app, along with their important context (param/argument/return/local variable values).  

You no longer need to debug with `binding.pry` or `puts` statements, as the entire callstack for a given request is captured.

Demo video:
[![Watch the video](https://user-images.githubusercontent.com/4600/190929740-fc68e18f-9572-41be-9719-cc6a8077e97f.png)](https://www.youtube.com/watch?v=NGqnwcNWv_k)

Class method calls are labeled.  Return values for those calls are denoted with ↳

Arguments for a method will be listed along with their calling values.

For method returns ↳, the final values of the local variables will be listed when you hover over the entry.

<img width="1695" alt="CleanShot 2022-09-17 at 21 10 32@2x" src="https://user-images.githubusercontent.com/4600/190882603-a99e9358-9754-4cbf-ac68-a41d53afe747.png">

Subsequent calls within a method are visibly nested.

Checkpoint is a Rails engine that you mount within your Rails app.

Here's a sample debugging sessions recorded from a Jumpstart Rails based app I've been working on.  This is a request for the main page ( https://smartk.id/ ).

![image](https://user-images.githubusercontent.com/4600/190882432-58092e38-7ee2-4138-b13a-f45ff2b09227.png)

Checkpoint Rails records all of the critical method calls within your app, along with their important context (param/argument/return/local variable values).

All in a rolling panel, so that you can debug your call chains from any point in the stack.

You'll never have to debug with `puts` statements ever again.

Calls are visibly nested so that it's easy to see which calls are issued from which parent methods.

## Installation
Add this line to your application's Gemfile:

```ruby
gem "checkpoint-rails"
```

Add the following to your routes file

```
  if Rails.env.development? || Rails.env.test?
    mount Checkpoint::Rails::Engine, at: "/checkpoint"
  end
```

And then execute:
```bash
$ bundle
```

## Usage
Open `http://localhost:3000/checkpoint/` in a separate tab.

Then open another page from your app.  E.g. the main page `http://localhost:3000`

Go back to the `http://localhost:3000/checkpoint/` tab. Observe the method call traces.

## Demo

You can view a demo here :

https://yxveq.hatchboxapp.com/

Click the "Checkpoint Debugger View" button.  The checkpoint debugger view opens in a separate tab.  Go back to https://yxveq.hatchboxapp.com/ and hit refresh.  

As you browse the sample demo app, you'll see a breakdown of the method calls in the traces/checkpoint debugger view.

## License
The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).
