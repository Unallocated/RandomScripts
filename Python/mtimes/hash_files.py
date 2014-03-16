#!/usr/bin/env python
## Generate File SHA1 hash values and mtime stamps.  Identify duplicates.
## Typical use to find duplicate files =  hash_files.py | sort
## 03/15/14 - Contributed to UAS RandomScripts
## 03/12/14 - Created

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

def push_mtimes():
  #mtime_datafile = '.mtimes.pickle'
  hashdic = dict()
  unique_qty = 0
  dupe_qty = 0  
  for dirpath, dirnames, files in os.walk('.'):
    # Recurse through the directory tree and ignore \. prefixed folders
    rgx = re.compile(r'\\\.')
    if not rgx.search(dirpath):
      for fname in files:
         if not fname == mtime_datafile:
          fpath = os.path.join(dirpath, fname);
          hashky = hashlib.sha1(io.open(fpath, "rb", buffering=0).readall()).hexdigest()
          # Check for uniqueness to prevent duplicates
          if not hashky in hashdic:
            unique_qty = unique_qty + 1
            hashdic[hashky] = os.stat(fpath).st_mtime_ns
            print('*', hashky, '*', fname, ';', dirpath)
            #print(len(hashdic), '*', hashlib.sha1(io.open(fpath, "rb", buffering=0).readall()).hexdigest(),
            #      '*', os.stat(fpath).st_mtime_ns,
            #      '*', fpath,
            #      '*', datetime.datetime.fromtimestamp(os.stat(fpath).st_mtime_ns))
          else:
            dupe_qty = dupe_qty + 1
            print('*', hashky, '+', fname, ';', dirpath)
            if os.stat(fpath).st_mtime_ns <  hashdic[hashky]:
              hashdic[hashky] = os.stat(fpath).st_mtime_ns

  #save_dictfile(hashdic, mtime_datafile)
  #print('Unique Files =', unique_qty)
  #print('  Duplicates =', dupe_qty)
  #print(' Total Files =', len(hashdic))

def main():
  push_mtimes()
  sys.exit(0)

if __name__ == '__main__':
  main()
