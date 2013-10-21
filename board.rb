#!/usr/bin/env ruby
require 'sinatra'
require 'shotgun'
require 'mongo'

include Mongo

#Global settings
$default_name = 'Aurelian'
$greeting = 'Aurelia unlimited'
$db_name = 'board'

mc = MongoClient.new('localhost', 27017)

#Init main db
$db = mc.db($db_name)

#Create sequence marker if not present (to label posts in order)
#if $db['seq'].find_all.to_a == [] then
#	$db['seq'].insert('pid' => 1)
#end

#def get_next_id
#	$db['seq'].findAndModify(
#          {
#            query: { _id: name },
#            update: { $inc: { seq: 1 } },
#            new: true
#          }
#   );
#end

class Board < Sinatra::Base
	
#	get '/board' do
#		redirect '/board/0'
#	end
	
	get '/hello' do
		'nyaaaaaaaaaaa'
	end
	
#	get %r{/board/([\d]+)} do
#		page = params[:captures].first
#		"GET page #{page}"
#	end
	
	get '/board/thread/:tid' do
		"GET tid #{params[:tid]}"
	end
	
	get '/board' do
	  threads = $db['threads'].find.to_a
	  first_posts = threads.map do |thread| $db['posts'].find(:tid => thread['_id']) end
	  erb "<html>
				<head>
					<title>Rubychan</title>
					<link href='/ice.css' type='text/css' rel='stylesheet'/>
					<meta http-equiv='Content-Type' content='text/html; charset=utf-8' />
				</head>
			<body>
			<div id='header'>
			<%= $greeting %>
			</div>
			<div id='submitform'>
			<center>
			<p style='font-size: 30px; font-style: italic'>Create new thread</p>
			<form name='input' action='newthread' method='post'>
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
				    <td>Captcha</td>
				    <td><input class='txtin' type='text' name='captcha'></td>
				</tr>
				</table>
				<input class='button' type='submit' value='Submit'>
			</form>
			</center>
			</div>
			<table>
				<% $db['threads'].find.each do |thread| %>
					<% $db['posts'].find('tid' => thread['_id']).each do |post| %>
					<tr><td>
						<div class='post'>
							<b>
							   <%= post['name'] %>
							   <%= post['created_at'].ctime %>
							</b>
							<div class='post_txt'><%= post['msg'] %></div>
						</div>
					</td></tr>
					<% end %>
				<% end %>
			</table>
			</body>
			</html>"
	end
	
	post '/newthread' do
		t = Time.now
		
		if params[:msg] == "" then
		    puts "[Empty thread #{t}]"
		    redirect '/empty_post'
		end
		
		if params[:name] == "" then
		    params[:name] = $default_name
		end
		
		puts "[New post #{t}]"
		
		tid = $db['threads'].insert(
		  :created_at => t
		)
		
		#Create new post document
		$db['posts'].insert(
		  :name      => params[:name],
		  :msg       => params[:msg],
		  :email     => params[:email],
		  :created_at => t,
		  :tid => tid
		)
		
		#Return back to 
		redirect '/board'
	end

end


