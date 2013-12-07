#!/usr/bin/env ruby
require 'sinatra'
require 'mongo'
require 'RMagick'
require 'digest/md5'
require 'fileutils'
require 'uri'
include Mongo

#Global settings
$default_name = 'Aurelian'
$db_name = 'board'
$threads_per_page = 10
$captcha_folder = 'public/captcha/'
$show_posts = 5

$thumb_side = 300
$max_file_size = 1100000 #bytes
$allowed_file_types = ['image/png', 'image/jpg', 'image/jpeg', 'image/gif']
$uri_regexp = URI.regexp(['http','https'])

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
	)['counter']
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

def transform_URIs(str)
    str.gsub($uri_regexp) { |capture| "<a href="+capture+">"+capture+"</a>" }
end

def transform_post_links(str)
    str.gsub(/&gt&gt[\d]+/) { |capture|
        id = capture[6..-1]
        "<a href=\"\#"+id+"\" class='internal-link'>"+"&gt&gt"+id+"</a>" }
end

def parse_user_text(str)
	transform_URIs(transform_post_links(str.gsub('<', '&lt').gsub('>', '&gt').gsub("\n", '<br>')))
end

def gen_page_bar
	n = $db['threads'].count/$threads_per_page
	hrefs = []
	(0..n).each {|i| hrefs << "/board/page/#{i}"}
	
	ERB.new("<div id='page_bar'>
		 <% for i in 0..n %>
		 <a class='undec' href=<%= hrefs[i] %>>[ <%= i %> ]&nbsp</a>
		 <% end %>
		 </div>").result(binding)
end

def get_image(post)
	image_code = ""
	if post["thumb"] and post["thumb"] != "" then
		image_code = "<a href=#{post['image']}><img style='float:left; margin: 15px;' src=#{post['thumb']}></img></a>"
	end
	return image_code
end

class Board < Sinatra::Base
	
	get '/board' do
		redirect '/board/page/0'
	end
	
	get '/board/' do
		redirect '/board/page/0'
	end
	
	get %r{/board/page/([\d]+)} do
		
		page = params[:captures].first.to_i
		
		#Check if page is in valid range
		if page > $db['threads'].count/$threads_per_page
			redirect '/board'
		end
		
		threads = $db['threads'].find.skip($threads_per_page*page).limit($threads_per_page).sort('last_post' => -1).to_a.map do |thread|
			
			post_count = $db['posts'].find(:tid => thread['_id']).count()
			
			if post_count <= $show_posts+1
				posts = $db['posts'].find(:tid => thread['_id']).sort("created_at" => 1).to_a
				first_post = posts[0]
				last_posts = posts[1..-1]
			else
				first_post = $db['posts'].find(:tid => thread['_id']).sort("created_at" => 1).limit(1).to_a.first
				last_posts = $db['posts'].find(:tid => thread['_id']).sort("created_at" => -1).limit($show_posts).to_a.reverse
			end
			
			{:thread => thread, :post_count => post_count, :first => first_post, :last => last_posts}
		end
		
		threads = threads.select {|x| x[:post_count] > 0}
		
	  	board_captcha = $db['global'].find_one({"board_captcha" => true})
	  	#Regenerate captcha is necessary
	  	if not board_captcha
			board_captcha = gen_captcha()
			$db['global'].insert({"board_captcha" => true, "captcha" => board_captcha})
		end
		board_captcha_path = "/captcha/" + board_captcha["captcha"] + ".jpg"
		
		thread_html = ""
	  	
		for thread in threads

			first_post = thread[:first]
			posts = thread[:last]
			tid = thread[:thread]['_id']
			tnum = thread[:thread]['num']
			
			thread_html += (erb("<tr><td>
									<div class='head_post' id=\"<%= first_post['num'].to_s %>\">
										<b>
								   		<%= first_post['name'] %>
								   		\| <%= first_post['created_at'].ctime %>
								   		\| <a class='post_num' href='/board/thread/<%= tnum %>#'
								   		      onclick='insert(<%= '\">>'+first_post['num'].to_s+'\"' %>)'>No.<%= first_post['num'].to_s %></a>
								   		\| <a class = 'reply' href='/board/thread/<%= tnum %>'>\[ Reply \]</a>
										</b>
									<br><%= image_code %><div class='post_txt'><%= first_post['msg'] %></div>
									</div>
									</td></tr>", :locals => {:first_post => first_post, :tnum => tnum, :image_code => get_image(first_post)}))
				for post in posts
					
					thread_html += (erb("<tr><td>
											<div class='post' id=\"<%= post['num'].to_s %>\">
												<b>
												   <%= post['name'] %>
												   \| <%= post['created_at'].ctime %>
												   \| <a class='post_num' href='/board/thread/<%= tnum %>' onclick='insert(<%= '\">>'+post['num'].to_s+'\"' %>)'>No.<%= post['num'].to_s %></a>
												</b>
												<br><%= image_code %><div class='post_txt'><%= post['msg'] %></div>
											</div>
											</td></tr>", :locals => {:post => post, :tnum => tnum, :image_code => get_image(post)}))
			end
		end

		code = erb("<html>
				<head>
					<title>Rubychan</title>
					<meta http-equiv='Content-Type' content='text/html; charset=utf-8' />
					<link href='/ice.css' type='text/css' rel='stylesheet'/>
					<script type='text/javascript' src='/sina.js'></script>
				</head>
			<body>
			<div id='header'>
			Aurelia unlimited
			</div>
			<div id='submitform'>
			<center>
			<p style='font-size: 30px; font-style: italic'>Create new thread</p>
			<form name='input' action='/newthread' method='post' enctype='multipart/form-data'>
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
					<td><textarea class='txtin' id ='msg_text' name='msg' rows='10' ></textarea></td>
				</tr>
				<tr>
					<td>File</td>
					<td><input type='file' name='attached_file'></td>
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
			<table>", :locals => {:board_captcha_path => board_captcha_path}) + thread_html +  "</table>" + gen_page_bar() + "</body></html>"
		erb code
	end
	
	get '/board/thread/:tnum' do
	    tnum = params[:tnum].to_i
		thread = $db['threads'].find_one(:num => tnum)
		
		if not thread
			redirect '/no_thread'
		end
		
		tid = thread['_id'].to_s
		tid_bson = thread['_id']
		
		thread_captcha = thread['captcha']
		
		#Regenerate captcha is necessary
		if not thread_captcha
			thread_captcha = gen_captcha()
			$db['threads'].update({"_id" => tid_bson}, {"$set" => {"captcha" => thread_captcha}})
		end
		
		thread_captcha_path = "/captcha/" + thread_captcha + ".jpg"
		
		posts = $db['posts'].find(:tid => tid_bson).sort("created_at" => 1).to_a
		
		thread_html = ""
		
		for post in posts
			
			thread_html += (erb("<tr><td>
									<div class='post' id=\"<%= post['num'].to_s %>\">
										<b>
										   <%= post['name'] %>
										   \| <%= post['created_at'].ctime %>
										   \| <a class='post_num' onclick='insert(<%= '\">>'+post['num'].to_s+'\"' %>)'>No.<%= post['num'].to_s %></a>
										</b>
										<br><%= image_code %><div class='post_txt'><%= post['msg'] %></div>
									</div>
									</td></tr>", :locals => {:post => post, :image_code => get_image(post)}))
		end
		
		thread_html = "<table>" + thread_html + "</table>"
		
		action = "/board/thread/#{tnum}/newpost"
		
		code = erb("<html>
				<head>
					<title>Rubychan</title>
					<meta http-equiv='Content-Type' content='text/html; charset=utf-8' />
					<link href='/ice.css' type='text/css' rel='stylesheet'/>
					<script type='text/javascript' src='/sina.js'></script>
				</head>
			<body>
			<a href='/board' class='undec'>
			<div id='header'>
			Aurelia unlimited
			</div>
			</a>
			<div id='submitform'>
			<center>
			<p style='font-size: 30px; font-style: italic'>Create new post</p>
			<form name='input' action=<%= action %> method='post' enctype='multipart/form-data'>
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
					<td><textarea class='txtin' id ='msg_text' name='msg' rows='10' ></textarea></td>
				</tr>
				<tr>
					<td>File</td>
					<td><input type='file' name='attached_file'></td>
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
			</div>", :locals => {:action => action, :thread_captcha_path => thread_captcha_path}) + thread_html + "</body></html>"
			
			erb code
	end
	
	post '/board/thread/:tnum/newpost' do
		t = Time.now
		
		#Check if post is empty
		if params[:msg] == "" then
		    puts "[Empty post #{t}]"
		    redirect '/empty_post'
		end
		
		tnum = params[:tnum].to_i
		thread = $db['threads'].find_one(:num => tnum)
		tid = thread['_id'].to_s
		tid_bson = thread['_id']
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
		
		#Verify attached file if any
		if params[:attached_file]
			if not $allowed_file_types.include? params[:attached_file][:type]
				redirect '/wrong_type'
			end
			if params[:attached_file][:tempfile].size > $max_file_size
				redirect '/wrong_size'
			end
		
			#Generate filename TODO: unique without random
			fname = t.to_i.to_s+rand(10000).to_s
			fext = /\/([a-z]+)/.match(params["attached_file"][:type]).to_s[1..-1]
			thumb_path = '/image/thumb/' + fname + '.jpg'
			image_path = '/image/' + fname + '.' + fext
		
			#Resize file if necessary
			img = Magick::Image::read(params[:attached_file][:tempfile].path).first
			#Write thumb
			img.resize_to_fit($thumb_side, $thumb_side).write('public' + thumb_path)
			#Write image
			temp_path = params[:attached_file][:tempfile].path
			fs_path = 'public' + image_path 
			FileUtils.cp( temp_path, fs_path )
			FileUtils.chmod( 0644, fs_path )
		else
			thumb_path = ""
			image_path = ""
		end
		
		#Update threads posting date
		$db['threads'].update({"_id" => tid_bson}, {"$set" => {"last_post" => t}})
		
		if params[:name] == ""
		    params[:name] = $default_name
		end
		
		puts "[New post #{t}]"
		
		post_number = get_next_id()
		
		#Create new post document
		$db['posts'].insert(
		  :name      => parse_user_text(params[:name]),
		  :msg       => parse_user_text(params[:msg]),
		  :email     => parse_user_text(params[:email]),
		  :thumb	 => thumb_path,
		  :image	 => image_path,
		  :created_at => t,
		  :tid => tid_bson,
		  :num => post_number
		)
		
		#Return back to 
		redirect "/board/thread/#{tnum}"

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
		
		#Verify attached file if any
		if not params[:attached_file]
			redirect '/nofile'
		end
		if not $allowed_file_types.include? params[:attached_file][:type]
			redirect '/wrong_type'
		end
		if params[:attached_file][:tempfile].size > $max_file_size
			redirect '/wrong_size'
		end
		
		#Generate filename TODO: unique without random
		fname = t.to_i.to_s+rand(10000).to_s
		fext = /\/([a-z]+)/.match(params["attached_file"][:type]).to_s[1..-1]
		thumb_path = '/image/thumb/' + fname + '.jpg'
		image_path = '/image/' + fname + '.' + fext
		
		#Resize file if necessary
		img = Magick::Image::read(params[:attached_file][:tempfile].path).first
		#Write thumb
		img.resize_to_fit($thumb_side, $thumb_side).write('public' + thumb_path)
		#Write image
		temp_path = params[:attached_file][:tempfile].path
		fs_path = 'public' + image_path 
		FileUtils.cp( temp_path, fs_path )
		FileUtils.chmod( 0644, fs_path )
		
		puts "[New thread #{t}]"
		
		post_number = get_next_id()
		
		tid = $db['threads'].insert(
		  :created_at => t,
		  :last_post => t,
		  :captcha => gen_captcha(),
		  :num => post_number
		)
		
		#Create new post document
		$db['posts'].insert(
		  :name      => parse_user_text(params[:name]),
		  :msg       => parse_user_text(params[:msg]),
		  :email     => parse_user_text(params[:email]),
		  :thumb	 => thumb_path,
		  :image	 => image_path,
		  :created_at => t,
		  :tid => tid,
		  :num => post_number
		)
		
		#Return back to 
		redirect '/board'
	end
end


