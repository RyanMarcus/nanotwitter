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

require 'sequel'
require 'sqlite3'

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

module Model

  def Model.all_tweets()
    tweets = DB[:tweet]
    tweets = tweets.join(:account, :account_id => :account_id)
    tweets = tweets.reverse_order(:when)
    return tweets.limit(100).all
  end

  def Model.tweets_by (user_id)
    tweets = DB[:tweet]
    tweets = tweets.join(:account, :account_id => :account_id)
    tweets= tweets.filter(:account__account_id => user_id)
    tweets = tweets.reverse_order(:when)
    return tweets.limit(100).all
  end

  def Model.get_name_of (user_id)
    accounts = DB[:account]
    user = accounts.filter(:account_id => user_id)

    if user.count() == 0
      return false
    end

    user = user.first
    return user[:email]
  end


  def Model.get_id_of (email)
    accounts = DB[:account]
    user = accounts.filter(:email => email)

    if user.count() == 0
      return false
    end

    user = user.first
    return user[:account_id]
  end


  def Model.test_credentials (email, password)
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

    return true, "Login OK"

  end


  def Model.create_account (email, password)
    if account_exists? email
      return false, "An account with that email address already exists"
    end

    accounts = DB[:account]
    pass_hash = BCrypt::Password.create(password)
    
    accounts.insert(:email => email, :password => pass_hash.to_s)
    return true, "account created!"
  end

  def Model.account_exists? (email)
    accounts = DB[:account]
    return accounts.filter(:email => email).count() != 0
  end

end
