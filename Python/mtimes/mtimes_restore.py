#!/usr/bin/env python
## Restore file mtimes
## 03/15/14 - Contributed to UAS RandomScripts
## 03/08/14 - Python bug in os.path.getmtime(path).  Must use os.stat(path).st_mtime_ns
## 03/03/14 - Restore the mtime Time Stamp for each file from the repository.

import os
import re
import shutil
import subprocess
import sys
import tempfile

import io
import hashlib
import datetime
import pickle
 
def system(*args, **kwargs):
    kwargs.setdefault('stdout', subprocess.PIPE)
    proc = subprocess.Popen(args, **kwargs)
    out, err = proc.communicate()
    return out
 
def save_dictfile(dictobj, fname ):
  # Pickle the dictionary object to a binary file
  with open(fname, 'wb') as ff:
    pickle.dump(dictobj, ff, pickle.HIGHEST_PROTOCOL)

def load_dictfile(fname):
  # Retrieve the dictionary pickle from its binary file
  with open(fname, 'rb') as ff:
    return pickle.load(ff)

def pop_mtimes():
  mtime_datafile = '.mtimes.pickle'
  hashdic = dict()
  hashdic = load_dictfile(mtime_datafile)
  print(len(hashdic), 'mtime stamps retrieved')
  ii = 0;
  for dirpath, dirnames, files in os.walk('.'):
    # Recurse through the directory tree and ignore \. prefixed folders
    rgx = re.compile(r'\\\.')
    if not rgx.search(dirpath):
      for fname in files:
        fpath = os.path.join(dirpath, fname);
        hashky = hashlib.sha1(io.open(fpath, "rb", buffering=0).readall()).hexdigest()
        # Lookup the Hash Key
        if hashky in hashdic:
          if os.stat(fpath).st_mtime_ns != hashdic[hashky]:
            ii = ii+1
            # verbose output
            print('*', hashlib.sha1(io.open(fpath, "rb", buffering=0).readall()).hexdigest(),
                  '*', os.stat(fpath).st_mtime_ns, '*', hashdic[hashky])
            oldtime = datetime.datetime.fromtimestamp(os.stat(fpath).st_mtime);
            os.utime(fpath, ns=(os.stat(fpath).st_mtime_ns, hashdic[hashky]))
            newtime = datetime.datetime.fromtimestamp(os.stat(fpath).st_mtime);
            print('**', oldtime, '**', newtime)
  print(ii, 'file timestamps restored')  

def main():
  pop_mtimes()
  sys.exit(0)

if __name__ == '__main__':
  main()
