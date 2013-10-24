#!/usr/bin/env ruby
require 'sinatra'
require 'shotgun'
require 'mongo'
require 'RMagick'
require 'digest/md5'
require 'fileutils'
include Mongo

#Global settings
$default_name = 'Aurelian'
$db_name = 'board'
$threads_per_page = 10
$captcha_folder = 'public/captcha/'

#Init db connection
mc = MongoClient.new('localhost', 27017)

#Init main db
$db = mc.db($db_name)

#Create sequence marker if not present (to label posts in order)

counter = $db['global'].find_one("_id" => "counter")
if not counter
	$db['global'].insert("_id" => "counter", "counter" => 1)
end

def get_next_id
	return $db['global'].find_and_modify(
		{
			"query" => { "_id" => "counter" },
			"update" => { "$inc" => { "counter" => 1 } },
			"new" => true
		}
	)
end

#simple captcha generator
#returns hashed captcha text
def gen_captcha
	captcha = ""
	5.times { captcha << (rand(26)+65).chr }
	hashed = Digest::MD5.hexdigest(captcha)
	
	canvas = Magick::Image.new(80,30, Magick::HatchFill.new('#ffffff','#0169e1'))

	text = Magick::Draw.new
	text.annotate(canvas,60,25,10,0,captcha) {
		    self.fill = "#000000"
		    self.stroke = "transparent"
		    self.pointsize = 22
		    self.font_weight = Magick::BoldWeight
		    self.gravity = Magick::SouthGravity
	}
	
	canvas = canvas.implode(-0.4)
	canvas.write($captcha_folder+hashed+".jpg")
	
	return hashed
end

def parse_user_text(str)
	str.gsub('<', '&lt').gsub('>', '&gt').gsub("\n", '<br>')
end

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
		
		tid = params[:tid]
		tid_bson = BSON::ObjectId.from_string(tid)
		thread = $db['threads'].find_one(:_id => tid_bson)
		
		if not thread
			redirect '/no_thread'
		end
		
		thread_captcha = thread['captcha']
		
		#Regenerate captcha is necessary
		if not thread_captcha
			thread_captcha = gen_captcha()
			$db['threads'].update({"_id" => tid_bson}, {"$set" => {"captcha" => thread_captcha}})
		end
		
		thread_captcha_path = "/captcha/" + thread_captcha + ".jpg"
		
		posts = $db['posts'].find(:tid => tid_bson).to_a
		
		thread_html = ""
		
		for post in posts
			thread_html += (erb("<tr><td>
									<div class='post'>
										<b>
										   <%= post['name'] %>
										   \| <%= post['created_at'].ctime %>
										</b>
										<div class='post_txt'><%= post['msg'] %></div>
									</div>
									</td></tr>", :locals => {:post => post}))
		end
		
		action = "/board/thread/#{tid}/newpost"
		
		code = erb("<html>
				<head>
					<title>Rubychan</title>
					<link href='/ice.css' type='text/css' rel='stylesheet'/>
					<meta http-equiv='Content-Type' content='text/html; charset=utf-8' />
				</head>
			<body>
			<div id='header'>
			Aurelia unlimited
			</div>
			<div id='submitform'>
			<center>
			<p style='font-size: 30px; font-style: italic'>Create new post</p>
			<form name='input' action=<%= action %> method='post'>
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
					<td><input id='captcha' type='text' name='captcha'>
						<div style='float:right; padding-top:3px; padding-right: 60px;'><img src=<%= thread_captcha_path %>></img></div></td>
				</tr>
				</table>
				<input class='button' type='submit' value='Submit'>
			</form>
			</center>
			</div>
			<table>", :locals => {:action => action, :thread_captcha_path => thread_captcha_path}) + thread_html + "</table></body></html>"
			
			erb code
	end
	
	get '/board' do
		
		threads = $db['threads'].find.sort('last_post.to_a.map do |thread|
			[ thread, $db['posts'].find(:tid => thread['_id']).to_a ]
		end
		
		threads = threads.select {|x| x[1].size > 0}
		
	  	board_captcha = $db['global'].find_one({"board_captcha" => true})
	  	#Regenerate captcha is necessary
	  	if not board_captcha
			board_captcha = gen_captcha()
			$db['global'].insert({"board_captcha" => true, "captcha" => board_captcha})
		end
		board_captcha_path = "/captcha/" + board_captcha["captcha"] + ".jpg"
		
		thread_html = ""
	  	
		for thread in threads

			posts = thread[1]
			first_post = posts[0]
			tid = thread[0]['_id']
			
			thread_html += (erb("<tr><td>
									<div class='head_post'>
										<b>
								   		<%= first_post['name'] %>
								   		\| <%= first_post['created_at'].ctime %>
								   		\| <a href=/board/thread/<%= tid %>>\[Reply\]</a>
										</b>
									<div class='post_txt'><%= first_post['msg'] %></div>
									</div>
									</td></tr>", :locals => {:first_post => first_post, :tid => tid}))
			if posts.size > 1 then
				for post in posts[1, posts.size-1]
					thread_html += (erb("<tr><td>
											<div class='post'>
												<b>
												   <%= post['name'] %>
												   \| <%= post['created_at'].ctime %>
												</b>
												<div class='post_txt'><%= post['msg'] %></div>
											</div>
											</td></tr>", :locals => {:post => post}))
				end
			end
		end

		code = erb("<html>
				<head>
					<title>Rubychan</title>
					<link href='/ice.css' type='text/css' rel='stylesheet'/>
					<meta http-equiv='Content-Type' content='text/html; charset=utf-8' />
				</head>
			<body>
			<div id='header'>
			Aurelia unlimited
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
					<td><input id='captcha' type='text' name='captcha'>
						<div style='float:right; padding-top:3px; padding-right: 60px;'><img src=<%= board_captcha_path %>></img></div></td>
				</tr>
				</table>
				<input class='button' type='submit' value='Submit'>
			</form>
			</center>
			</div>
			<table>", :locals => {:board_captcha_path => board_captcha_path}) + thread_html +  "</table></body></html>"
		erb code
	end
	
	post '/board/thread/:tid/newpost' do
		t = Time.now
		
		#Check if post is empty
		if params[:msg] == "" then
		    puts "[Empty post #{t}]"
		    redirect '/empty_post'
		end
		
		tid = params[:tid]
		tid_bson = BSON::ObjectId.from_string(tid)
		thread = $db['threads'].find_one(:_id => tid_bson)
		thread_captcha = thread['captcha']
		
		#Verify captcha
		if Digest::MD5.hexdigest(params[:captcha]) != thread_captcha
			redirect '/wrong_captcha'
		end
		
		#if verification is Ok then update captcha for thread:
		thread_captcha_old = thread_captcha
		
		thread_captcha = gen_captcha()
		$db['threads'].update({"_id" => tid_bson}, {"$set" => {"captcha" => thread_captcha}})
		
		#remove old captcha:
		FileUtils.rm 'public/captcha/' + thread_captcha_old + '.jpg'
		
		#Update threads posting date
		$db['threads'].update({"_id" => tid_bson}, {"$set" => {"last_post" => t}})
		
		if params[:name] == ""
		    params[:name] = $default_name
		end
		
		puts "[New post #{t}]"
		
		tid = params[:tid]
		
		#Create new post document
		$db['posts'].insert(
		  :name      => parse_user_text(params[:name]),
		  :msg       => parse_user_text(params[:msg]),
		  :email     => parse_user_text(params[:email]),
		  :created_at => t,
		  :tid => BSON::ObjectId.from_string(tid)
		)
		
		#Return back to 
		redirect "/board/thread/#{tid}"

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
		
		board_captcha = $db['global'].find_one({"board_captcha" => true})["captcha"]
		
		#Verify captcha
		if Digest::MD5.hexdigest(params[:captcha]) != board_captcha
			redirect '/wrong_captcha'
		end
		
		#if verification is Ok then update captcha for board:
		board_captcha_old = board_captcha
		
		board_captcha = gen_captcha()
		$db['global'].update({"board_captcha" => true}, {"$set" => {"captcha" => board_captcha}})
		
		#remove old captcha:
		FileUtils.rm 'public/captcha/' + board_captcha_old + '.jpg'
		
		puts "[New thread #{t}]"
		
		tid = $db['threads'].insert(
		  :created_at => t,
		  :last_post => t,
		  :captcha => gen_captcha()
		)
		
		#Create new post document
		$db['posts'].insert(
		  :name      => parse_user_text(params[:name]),
		  :msg       => parse_user_text(params[:msg]),
		  :email     => parse_user_text(params[:email]),
		  :created_at => t,
		  :tid => tid
		)
		
		#Return back to 
		redirect '/board'
	end

end


