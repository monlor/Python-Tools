# encoding: utf-8
from selenium import webdriver
from selenium.webdriver.chrome.options import Options
#from selenium.webdriver.common.by import By
from selenium.webdriver.support.ui import WebDriverWait
import time
import urllib2
import sys
import os
import re

reload(sys);  
sys.setdefaultencoding("utf8")  
chrome_options = Options()
chrome_options.add_argument('--headless')
chrome_options.add_argument('--disable-gpu')
driver = webdriver.Chrome(chrome_options=chrome_options)
driver2 = webdriver.Chrome(chrome_options=chrome_options)
request_url="http://music.sonimei.cn/"
#request_url="https://music.2333.me/"
driver.get(request_url)
driver.find_elements_by_class_name("am-radio-inline")[1].click()
args = sys.argv
times = 5
# 获取参数
try:
	arg1 = args[1]
except Exception:
	arg1 = "./songs.txt"
try: 
	arg2 = args[2]
except Exception:
	arg2 = "./"
else:
	if not os.path.exists(arg2):
		os.makedirs(arg2)

#读取歌曲文件
try:
	f = open(arg1, 'r')
except Exception:
	print("请输入正确的歌曲文件路径！")
	exit()
else:
	def download_failed(line):
		global times
		print("\t歌曲下载过程出错，重新下载...")
		driver.get(request_url)
		if times>0:
			f.seek(-readlen,1)
		else:
			print("\t经过多次尝试失败，可能找不到下载资源或歌曲资料！")
			with open(arg2+"/failed.txt","a") as f2:
				f2.write(line+"\n")
			times = 5
		times=times-1
	
	while True:
		head=f.tell()
		line=f.readline()
		readlen=f.tell()-head
		if not line:
			print("歌曲下载完毕！")
			break
		line = line.strip("\n").decode()
		print("准备下载歌曲【%s】："%(line))
		bar = driver.find_element_by_id("j-input")	
		# 添加输入框内容
		try:
			bar.clear()
		except Exception:
			driver.get(request_url)
		bar.send_keys(line)
		time.sleep(1)
		driver.find_element_by_id("j-submit").click()

		try:
			# 等在音乐作者信息加载
			element = WebDriverWait(driver,25).until(lambda x:driver.find_element_by_class_name("aplayer-author").text)
		except Exception:
			download_failed(line)
			continue

		# 获取下载地址信息
		url=driver.find_element_by_id("j-src-btn").get_attribute("href")
		# 歌曲名称
		title=driver.find_element_by_class_name("aplayer-title").text
		# 作者名，显示问题，名字前面有-
		author=driver.find_element_by_class_name("aplayer-author").text
		# 该歌曲的qq音乐地址
		qqurl=driver.find_element_by_id("j-link-btn").get_attribute("href")
		# 获取音乐ID
		# musicid=re.findall(r"song/(.+?)\.",qqurl)[0]
		# print("%s %s,%s"%(title,author,url))
		# 返回主页
		driver.find_element_by_id("j-back").click()	
		
		# 下载歌曲
		try:
			print("\t下载歌曲文件...")
			furl = urllib2.urlopen(url)
			data = furl.read()
			music_path=arg2+"/"+title+" "+author+".mp3"
			with open(music_path,"wb") as code:
				code.write(data)
		except Exception:
			download_failed(line)
			continue

		# 插入音乐专辑图等信息
		print("\t写入歌曲信息...")
		# 根据歌曲id进入qq音乐，获取歌曲信息
		driver2.get(qqurl)
		try:
			# 等待音乐年份信息加载
			element = WebDriverWait(driver,10).until(lambda x:driver2.find_elements_by_class_name("data_info__item")[4].text)
		except Exception:
			pass
		
		# 专辑图地址
		try:
			picurl=driver2.find_element_by_css_selector(".data__cover img").get_attribute("src")
		except Exception:
			download_failed(line)
			continue
		# 艺术家
		artist=driver2.find_element_by_class_name("data__singer").text.encode("utf-8")
		data_info=driver2.find_elements_by_class_name("data_info__item")
		# 专辑名
		try:
			malbum=data_info[0].find_element_by_tag_name("a").text.encode("utf-8")
		except Exception:
			malbum="UnKnow"
		else:
			# 歌曲类型
			mtype=data_info[2].text.encode("utf-8")
		try:
			mtype=(re.findall(r"：(.+?)$",mtype))[0]
		except Exception:
			mtype="UnKnow"
		else:
			# 歌曲年份
			mtime=data_info[4].text.encode("utf-8")
		try:
			mtime=(re.findall(r"：(.+?)-",mtime))[0]
		except Exception:
			mtime=""
		
		# 下载专辑图
		try:
			furl = urllib2.urlopen(picurl)
			data = furl.read()
			pic_path=arg2+"/"+title+" "+author+".jpg"
			with open(pic_path,"wb") as code:
				code.write(data)
		except Exception:
			download_failed(line)
			continue
		else:
			#写入专辑信息 lame
			os.system("lame -b 512 --ti "+"\""+pic_path+"\" "+"\""+music_path+"\""+" --tt \""+title+"\" --ta \""+artist+"\" --tl \""+malbum+"\" --ty \""+mtime+"\" --tg \""+mtype+"\" &> /dev/null")
			os.system("rm -rf \""+pic_path+"\"")
			os.system("mv \""+music_path+"\".mp3 \""+music_path+"\"")
			times = 5


finally:
	driver.quit()
	driver2.quit()
	f.close()


