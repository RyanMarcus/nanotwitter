# Copyright 2014 Ryan Marcus
# This file is part of Nanotwitter.
#  
# Nanotwitter is free software: you can redistribute it and/or modify
# it under the terms of the GNU Affero General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#  
# Nanotwitter is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU Affero General Public License for more details.
#  
# You should have received a copy of the GNU Affero General Public License
# along with Nanotwitter.  If not, see <http://www.gnu.org/licenses/>.

require 'sinatra'
require 'sequel'
require 'bcrypt'
require 'digest/md5'
require 'sqlite3'

enable :sessions
set :session_secret, 'super secret'

DB = Sequel.sqlite("nano.db") # an in-memory database

DB.create_table? :account do
  primary_key :account_id
  String :email
  String :password
end

DB.create_table? :tweet do
  primary_key :id
  foreign_key :account_id, :account
  String :text
  DateTime :when
end

DB.create_table? :follow do
  foreign_key :user, :account
  foreign_key :follows, :account
end


get '/' do
  erb :index, :locals => { :tweets => all_tweets }
end

post '/login' do
  if not params.has_key?("email") or not params.has_key?("password")
    return erb :index, :locals => {:error_message => "You must specifiy an email and a password to login" }
  end
  
  valid, message = try_login(params[:email], params[:password])
  if not valid
    return erb :index, :locals => {:error_message => message}
  end

  redirect "/home"

end

get '/register' do
  erb :register
end

post '/register' do
  if not params.has_key?("email") or params[:email].length == 0
    logger.info "User did not specify an email address!"
    return erb :register, :locals => {:error_message => "You must enter an email address!"}
  end

  if not params.has_key? "password1" or params[:password1].length == 0
    return erb :register, :locals => {:error_message => "You must enter a password!"}
  end

  if not params.has_key? "password2" or params[:password2].length == 0
    return erb :register, :locals => {:error_message => "You must confirm your password!"}
  end

  if params[:password1] != params[:password2]
    return erb :register, :locals => {:error_message => "Your password entries did not match"}
  end

  # try to create the account
  valid, message = create_account(params[:email], params[:password1])
  if not valid
    return erb :register, :locals => {:error_message => message}
  end

  logger.info "All went well with account creation..."
  return erb :index, :locals => { :account_created => "yes" }

end

get '/home' do
  if not logged_in?
    return redirect "/"
  end

  erb :home, :locals => {:user => current_user, :tweets => all_tweets }
end

post '/tweet' do
  if not logged_in?
    return redirect "/"
  end
  
  tweets = DB[:tweet]
  tweets.insert(:account_id => current_user_id,
                :text => params[:text],
                :when => DateTime.now)

  redirect "/home"
end

get '/logout' do
  session[:value] = nil
  return redirect "/"
end

get '/profile/:id' do |user_id|
  if not logged_in?
    return redirect "/"
  end

  erb :profile, :locals => {:user => user_id, :tweets => tweets_by(user_id)}
end

def all_tweets()
  tweets = DB[:tweet]
  tweets = tweets.join(:account, :account_id => :account_id)
  tweets = tweets.reverse_order(:when)
  return tweets.limit(100).all
end

def tweets_by(user_id)
  tweets = DB[:tweet]
  tweets = tweets.join(:account, account_id: :account_id)
  tweets= tweets.filter(Sequel[:tweet][:account_id] => user_id)
  tweets = tweets.reverse_order(:when)
  return tweets.limit(100).all
end

def logged_in?()
  return session[:value] != nil
end

def current_user()
  return session[:value]
end

def current_user_id()
  accounts = DB[:account]
  user = accounts.filter(:email => current_user)

  if user.count() == 0
    return false
  end

  user = user.first
  return user[:account_id]
end

def get_name_of (user_id)
  accounts = DB[:account]
  user = accounts.filter(:account_id => user_id)

  if user.count() == 0
    return false
  end

  user = user.first
  return user[:email]
end

def try_login (email, password)
  accounts = DB[:account]
  user = accounts.filter(:email => email)

  if user.count() == 0
    return false, "No user is registered with that email address"
  end

  user = user.first
  pass_hash = BCrypt::Password.new(user[:password])

  if not pass_hash == password 
    return false, "Invalid password"
  end

  
  session[:value] = email

  return true, "Login OK"

end


def create_account (email, password)
  if account_exists? email
    return false, "An account with that email address already exists"
  end

  accounts = DB[:account]
  pass_hash = BCrypt::Password.create(password)
  
  accounts.insert(:email => email, :password => pass_hash.to_s)
  return true, "account created!"
end

def account_exists? (email)
  accounts = DB[:account]
  return accounts.filter(:email => email).count() != 0
end

def get_gravatar (email)
  # https://en.gravatar.com/site/implement/images/ruby/
  # get the email from URL-parameters or what have you and make lowercase
  email_address = email.downcase
  
  # create the md5 hash
  hash = Digest::MD5.hexdigest(email_address)
  
  # compile URL which can be used in <img src="RIGHT_HERE"...
  image_src = "http://www.gravatar.com/avatar/#{hash}"
  return image_src
end
