#!/usr/bin/env ruby
#This file contains utilities for administrating ruby imageboard engine

require 'mongo'
require 'RMagick'
require 'digest/md5'
require 'fileutils'
include Mongo

#Global settings
$db_name = 'board'
$captcha_folder = 'public/captcha/'

#Init db connection
mc = MongoClient.new('localhost', 27017)

#Init main db
$db = mc.db($db_name)

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

def rebuild_captcha
	
	puts 'Rebuilding captchas'
	
	threads = $db['threads'].find.to_a
	
	puts "#{threads.size} threads found"
	
	FileUtils.rm_rf(Dir.glob($captcha_folder + '*'))
	
	threads.each do |thr|
		thread_captcha = gen_captcha()
		
		puts thr["_id"].to_s
		
		$db['threads'].update({"_id" => thr["_id"]}, {"$set" => {"captcha" => thread_captcha}})
	end
	
	board_captcha = $db['global'].find_one({"board_captcha" => true})
	
	if not board_captcha
		board_captcha = gen_captcha()
		$db['global'].insert({"board_captcha" => true, "captcha" => board_captcha})
	else
		$db['global'].update({"board_captcha" => true}, {"$set" => {"captcha" => board_captcha}})
	end
	
	puts "Captcha rebuild complete"
end

def list_threads
	puts 'Listing captchas'
	threads = $db['threads'].find.each do |thr| puts thr end
end

eval ARGV[0]



