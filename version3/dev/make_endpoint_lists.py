#!/usr/bin/python2.6
# -*- coding: utf-8 -*-


import httplib, base64, json, ssl
import sys
import time
from logging.handlers import RotatingFileHandler
import logging
from shutil import copyfile


API_URL =  "https://10.11.0.81:9060/ers/config/endpoint"

DB_NAME = "engineering"
DB_USER = "test"
DB_PASSWORD = "password"

ISE_HOST = "66.86.125.12"
ISE_PORT = "9060"
ISE_USER = "ersadmin"
ISE_PASS = "Opasnet1!"

ISE_ENDPOINT_URI = '/ers/config/endpoint'
ISE_GROUP_URI = '/ers/config/endpointgroup'

CUBEMOBILE_ID = "0a48e680-d322-11ea-8b74-aef7c41e37a4"
CUBEPC_ID = "00173090-d322-11ea-8b74-aef7c41e37a4"
CUBEVDI_ID = "05d93050-d322-11ea-8b74-aef7c41e37a4"

# logfile = "/home/saisei/dev/engineering/ise_api.log"
LOG_FILENAME = "/var/log/batch_make.log"
LIST_PATH = "/var/log/batch_lists/"

logger = None

def make_logger():
    global logger
    try:
        logger = logging.getLogger('batch_make')
        fh = RotatingFileHandler(LOG_FILENAME, 'a', 50 * 1024 * 1024, 4)
        logger.setLevel(logging.INFO)
        formatter = logging.Formatter('%(asctime)s - %(name)s - %(levelname)s - %(message)s')
        fh.setFormatter(formatter)
        logger.addHandler(fh)
    except Exception as e:
        # print('cannot make logger, please check system, {}'.format(e))
        sys.exit()
    else:
        logger.info("***** logger starting %s *****" % (sys.argv[0]))



def init_file(filename):
    try:
        f = open(LIST_PATH+filename, 'w')
    except Exception as e:
        logger.error("init_file: {}".format(e))
    else:
        f.close()


def write_to_flie(filename, endpoint):
    with open(LIST_PATH+filename, 'a') as fh:
        fh.write(endpoint + '\n')    


def get_data_from_ise(verb, uri, headers):
    #context = ssl.create_default_context()
    #context.verify_mode = ssl.CERT_NONE
    #context.check_hostname = False

    conn = httplib.HTTPSConnection(ISE_HOST, ISE_PORT)
    conn.request(verb, uri, headers=headers)
    r = conn.getresponse()
    data = json.loads(r.read())
    
    return data


def main():
    start_time = time.time()
    # r = requests.get(api_url, headers=headers, auth=(REST_USER, REST_PASSWORD), verify=False)
    
    init_file('ise_cubepc_endpoint_lists.txt.tmp')
    init_file('ise_cubemobile_endpoint_lists.txt.tmp')
    init_file('ise_cubevdi_endpoint_lists.txt.tmp')
    init_file('ise_others_endpoint_lists.txt.tmp')
    
    headers = { 
    'Authorization': 'Basic %s' % base64.encodestring('%s:%s' % (ISE_USER, ISE_PASS)).replace('\n', ''),
    'Content-Type': 'application/json',
    'Accept': 'application/json'
    }

    data = get_data_from_ise('GET', ISE_GROUP_URI, headers)
    for resource in data["SearchResult"]["resources"]:
        if resource["name"] == 'CUBEPC':
            CUBEPC_ID = resource["id"]
        elif resource["name"] == 'CUBEMOBILE':
            CUBEMOBILE_ID = resource["id"]
        elif resource["name"] == 'CUBEVDI':
            CUBEVDI_ID = resource["id"]
        else:
            pass

    data = get_data_from_ise('GET', ISE_ENDPOINT_URI, headers)

    _total_count = data["SearchResult"]["total"]
    # _total_pages = (_total_count / 20)+1
    _total_pages = (_total_count / 100)+1
    _endpoint_id = []
    _endpoint_mac = []
    for _page in xrange(1, _total_pages+1):
        # print(str(_page)+"..")
        logger.info("{}/{}..".format(str(_page), str(_total_pages)))
        data = get_data_from_ise('GET', ISE_ENDPOINT_URI+'?size=100'+'&page='+str(_page), headers)
        _resource = data["SearchResult"]["resources"]
        for i, _endpoint in enumerate(_resource, 1):
            
            data = get_data_from_ise('GET', ISE_ENDPOINT_URI+"/"+_endpoint["id"], headers)
            _endpoint_group_id = data["ERSEndPoint"]["groupId"]

            if _endpoint_group_id == CUBEPC_ID:
                # print("PC: "+_endpoint["name"].lower())
                write_to_flie("ise_cubepc_endpoint_lists.txt.tmp", _endpoint["name"].lower())
            elif _endpoint_group_id == CUBEMOBILE_ID:
                # print("MOBILE: "+_endpoint["name"].lower())
                write_to_flie("ise_cubemobile_endpoint_lists.txt.tmp", _endpoint["name"].lower())                    
            elif _endpoint_group_id == CUBEVDI_ID:
                # print("VDI: "+_endpoint["name"].lower())
                write_to_flie("ise_cubevdi_endpoint_lists.txt.tmp", _endpoint["name"].lower())
            else:
                # print("OTHERS: "+_endpoint["name"].lower())
                write_to_flie("ise_others_endpoint_lists.txt.tmp", _endpoint["name"].lower())

    copyfile(LIST_PATH+"ise_cubepc_endpoint_lists.txt.tmp", LIST_PATH+"ise_cubepc_endpoint_lists.txt")
    copyfile(LIST_PATH+"ise_cubemobile_endpoint_lists.txt.tmp", LIST_PATH+"ise_cubemobile_endpoint_lists.txt")
    copyfile(LIST_PATH+"ise_cubevdi_endpoint_lists.txt.tmp", LIST_PATH+"ise_cubevdi_endpoint_lists.txt")
    copyfile(LIST_PATH+"ise_others_endpoint_lists.txt.tmp", LIST_PATH+"ise_others_endpoint_lists.txt")
    # print("--- %s seconds ---" % (time.time() - start_time)) #  587.746279001 sec


make_logger()

if __name__ == "__main__":
    while True:
        try:
            main()
        except KeyboardInterrupt:
            logger.info("The script is terminated by interrupt!")
            # print("\r\nThe script is terminated by user interrupt!")
            # print("Bye!!")
            sys.exit()
        time.sleep(3600)





    # for i, endpoint in enumerate(_resource, 1):
    #     # print(i, endpoint)
    #     _endpoint_id.append(endpoint["id"])
    #     _endpoint_mac.append(endpoint["name"])

# for i, _id in enumerate(_endpoint_id):
#     print(i+"..")
#     # r = requests.get(api_url+"/"+_id, headers=headers, auth=(REST_USER, REST_PASSWORD), verify=False)
#     # ers_endpoint=r.json()
#     conn = httplib.HTTPSConnection('10.11.0.81', 9060, context=ssl._create_unverified_context())
#     conn.request('GET', '/ers/config/endpoint/'+_id, headers=headers)
#     r = conn.getresponse()
#     ers_endpoint = json.loads(r.read())
#     # print(ers_endpoint)
#     _endpoint_group_id = ers_endpoint["ERSEndPoint"]["groupId"]
#     if _endpoint_group_id == _groupId:
#         print(_endpoint_mac[i])
# resp = conn.getresponse()


# class MysqlController:
#     def __init__(self, host, id, pw, db_name):
#         self.conn = pymysql.connect(host=host, user= id, password=pw, db=db_name, charset='utf8')
#         self.curs = self.conn.cursor()

#     def insert_total(self,total):
#         sql = 'INSERT INTO entire_nodes (count_of_nodes) VALUES (%s)'
#         self.curs.execute(sql,(total,))
#         self.conn.commit()

#     def get_internal(self):
#         sql = 'select member_id, mac_address from (select * from internal_assets_mac where not as_cls_cd = 1 or not as_ident_cd = 1 or not as_detail_cd = 5);'
#         self.curs.execute(sql)
#         return self.curs.fetchall()

#     def get_zeroclient(self):
#         sql= 'select member_id, mac_address from internal_assets_mac where internal_assets_mac.member_id = username and as_cls_cd = 1 and as_ident_cd = 1 and as_detail_cd = 5'
#         self.curs.execute(sql)
#         return self.curs.fetchall()

#     def get_external(self):
#         sql = 'select member_id, mac_address from mobile_mac;'
#         self.curs.execute(sql)
#         return self.curs.fetchall()
#         # print(self.curs.fetchall())

#         # self.conn.commit()

# conn = MysqlController('localhost', DB_USER, DB_PASSWORD, db_name)
# result=conn.get_external()

# # print(result)
# # print(result[0][2])
# # print(conn)
# _mac=[]
# with open(logfile, 'r') as f:
#     lines = f.readlines()
#     # print(lines)
#     for line in lines:
#         _mac.append(line.rstrip('\n'))    
#     # f.write(name+","+description+","+mac_address+"\n")


# for row in result:
#     # print(row)
#     for i, col in enumerate(row):
#         if i == 0:
#             # name = col
#             name = col
#             # name.decode('utf_8')
#         if i == 1:
#             # print(col)
#             try:
#                 col = col.upper()
#                 mac_address = col[0:2]+":"+col[2:4]+":"+col[4:6]+":"+col[6:8]+":"+col[8:10]+":"+col[10:12]
#             except Exception as e:
#                 pass
#             description = "SEC_VDI"
#             if mac_address not in _mac:
#                 # print(mac_address)
#                 r = requests.post(api_url, headers=headers, auth=(REST_USER, REST_PASSWORD), json={
#                     "ERSEndPoint" : {
#                     "name" : name,
#                     "description" : description,
#                     "mac" : mac_address,
#                     "groupId" : "f7684df0-d20c-11ea-be06-aef7c41e37a4",
#                     "staticGroupAssignment" : "true"
#                     }
#                 }, verify=False)
#                 with open(logfile, 'a') as f:
#                     f.write(mac_address+"\n")
#                 print("({}) is updated in ISE with code ({})..".format(mac_address, r.status_code))
#             else:
#                 print("There is no mac_address that is updated..")
#                 # pprint.pprint(r)
