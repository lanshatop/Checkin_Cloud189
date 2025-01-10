#!/usr/bin/python3
# -*- coding: utf-8 -*-
import requests
import json
import sys
import os
import time
headers = {'Content-Type': 'application/json;charset=utf-8'}
time=time.strftime("%Y-%m-%d %H:%M:%S", time.localtime())
api_url = "https://oapi.dingtalk.com/robot/send?access_token=a7055950aa9349f1e994f7a0127691e8ecd97eb8c81d7cff341d51734d7925a8"
def msg(text,user):
  json_text= {
     "msgtype": "markdown",
        "markdown": {
            "title": "Kasar",
            "text": text   + "\n \n @"+ user
        },
        "at": {
            "atMobiles": [
                user
 ],
            "isAtAll": False
        }
    }
  r = requests.post(api_url,data=json.dumps(json_text),headers=headers).json()
  code = r["errcode"]
if __name__ == '__main__':
    text = sys.argv[2]
    user = sys.argv[1]
    msg(text,user)