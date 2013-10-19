#!/usr/bin/env ruby
require 'sinatra'
require 'data_mapper'

#Global settings
$default_name = 'Rubyist'
$greeting = 'Welcome to the ruby processing facility'

#Sinatra server setting
#set :server, %w[thin webrick]

# A Sqlite3 connection to a persistent database
#DataMapper::Logger.new($stdout, :debug)
DataMapper.setup(:default, "sqlite://#{Dir.pwd}/posts.db")

#Data Models
class Post
  include DataMapper::Resource

  property :id,         Serial    # An auto-increment integer key
  property :name,       String    # A varchar type string, for short strings
  property :email,      String
  property :msg,        Text      # A text block, for longer string data.
  property :created_at, DateTime  # A DateTime, for any date you might like.
end

DataMapper.auto_upgrade! #Incremental upgrade
#DataMapper.auto_migrate! #Destructively drops and recreates tables
DataMapper.finalize

class Board < Sinatra::Base

	#Sinatra request handling
	#get '/' do
	  #redirect '/index.html'
	  #redirect '/board'
	#end

	get '/board' do
	  erb "
	<html>
		<head>
		    <title>Rubychan</title>
		    <style type='text/css'>
			  body { background-color: #4C001F;
			         color: #1D2535; }
			  #inptab { background-color: #4C2E2E;
			            color: #FF3333;
			            font-size: 25px;
			            font-style: italic;
			            text-align: center;
			            -moz-border-radius: 10px;
			             border-radius: 10px;
			             padding: 10px; }
			  #header { text-align: center;
			            font-size: 40px;
			            font-style: italic;
			            background-color: #4C2E2E;
			            color: #FF3333;
			            padding: 10px;
			            -moz-border-radius: 10px;
	  	                border-radius: 10px  }
			  #submitform { background-color: #826D6D;
			                padding: 10px;
			                text-align: center;
			                overflow: visible;
			                visibility: visible;
			                display: block;
			                -moz-border-radius: 10px;
			                border-radius: 10px;
			                margin-top: 10px;
			                margin-bottom: 10px; }
			  div.post { background-color: #826D6D;
			             -moz-border-radius: 10px;
			             border-radius: 10px;
			             font-size: 20px;
			             border-radius: 10px;
			             padding: 5px;
			             margin-top: 10px;
		                 margin-bottom: 10px; }
		                 
			  p.post_txt { font-size: 20px;
			               font-style: bold;
			               color: #FFBBBB; }
			               
			  input.button { color: #FF3333;
			                 text-align: center;
			                 font-size: 20px;
			                 padding: 10px;
			                 margin: 10px;
			                 width: 150px; }
			  
			  input.txtin { background-color: #826D6D;
			                font-size: 20px;
			                width: 600px;
			                color: #FFBBBB;
			                border-style: none;
			                -moz-border-radius: 10px;
			                 border-radius: 10px;
			                 padding: 5px;
			                 margin: 3px;}
			                
			  textarea.txtin { background-color: #826D6D;
			                width: 600px;
			                font-size: 20px;
			                color: #FFBBBB;
			                border-style: none;
			                -moz-border-radius: 10px;
			                 border-radius: 10px;
			                 padding: 5px;
		   	                 margin: 3px;}
			</style>
			<meta http-equiv='Content-Type' content='text/html; charset=utf-8' />
		</head>
	<body>
	<div id='header'>
	<%= $greeting %>
	</div>
	<div id='submitform'>
		<br>
		<center>
		<form name='input' action='newpost' method='post'>
		    <table id='inptab'>
		    <tr>
		        <td>Name</td>
		        <td><input class='txtin' type='text' name='name' ></td>
		    </tr>
		    <tr>
		        <td>Email</td>
		        <td><input class='txtin' type='text' name='email' ></td>
		    </tr>
		    <tr>
		        <td>Message</td>
		        <td><textarea class='txtin' name='msg' rows='10' ></textarea></td>
		    </tr>
		    <tr>
		        <td>CAPTCHA</td>
		        <td><input class='txtin' type='text' name='captcha' ></td>
		    </tr>
		    </table>
		<input class='button' type='submit' value='Send'>
		</form>
		</center>
	</div>
	<% posts = Post.all %>
	<% posts.each do |post| %>
	<div class='post'>
		<b>
		   <%= post.name %>
		   <%= post.created_at.ctime %>
		</b>
		<p class='post_txt'><%= post.msg %></p>
	</div>
	<% end %>
	</body>
	</html>"
	end

	post '/newpost' do
		t = Time.now
		
		if params[:msg] == "" then
		    puts "[Empty post #{t}]"
		    redirect '/board'
		end
		
		if params[:name] == "" then
		    params[:name] = $default_name
		end
		
		puts "[New post #{t}]"
		
		#Create new post record
		post = Post.create(
		  :name      => params[:name],
		  :msg       => params[:msg],
		  :email     => params[:email],
		  :created_at => t
		)    
		
		#Return back to 
		redirect '/board'
	end

end
