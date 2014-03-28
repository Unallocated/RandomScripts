#!/usr/bin/env python
## Save file mtimes
## 03/28/14 - Save as text CSV file. Compatibility problems with Dictionary in Pickle file between Python Versions
## 03/15/14 - Contributed to UAS RandomScripts
## 03/06/14 - for pre-commit hook script, uncomment the #*GIT*# line
## 03/03/14 - Save Oldest mtime Time Stamp for each file in the repository so it can be restored by post-update

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
    # Save the dictionary object to a text file
    with open(fname, 'w') as ff:
        for kv in dictobj.items():
            ff.write("%s,%s\n" % kv)
    
def load_dictfile(fname):
    # Retrieve the dictionary from its text file
    di = dict()
    with open(fname, 'r') as ff:
        for li in ff:
            li = li.rstrip ('\n')
            kv = li.split (',')
            di[kv[0]] = int(kv[1])
    return di

def push_mtimes():
    mtime_datafile = '.mtimes.csv'
    hashdic = dict()
    for dirpath, dirnames, files in os.walk('.'):
        # Recurse through the directory tree and ignore \. prefixed folders
        rgx = re.compile(r'\\\.')
        if not rgx.search(dirpath):
            for fname in files:
                fpath = os.path.join(dirpath, fname);
                hashky = hashlib.sha1(io.open(fpath, "rb", buffering=0).readall()).hexdigest()
                # Check for uniqueness to prevent duplicates
                if not hashky in hashdic:
                    hashdic[hashky] = os.stat(fpath).st_mtime_ns
                    #print(len(hashdic), '*', hashky, '+', hashdic[hashky])
                    ##verbose output
                    ##print(len(hashdic), '*', hashlib.sha1(io.open(fpath, "rb", buffering=0).readall()).hexdigest(),
                    ##      '*', os.stat(fpath).st_mtime_ns,
                    ##      '*', fpath,
                    ##      '*', datetime.datetime.fromtimestamp(os.stat(fpath).st_mtime_ns))
                elif os.stat(fpath).st_mtime_ns <  hashdic[hashky]:
                    hashdic[hashky] = os.stat(fpath).st_mtime_ns
                    #print(len(hashdic), '*', hashky, '..', hashdic[hashky])

    save_dictfile(hashdic, mtime_datafile)
    #For use as a Git pre-commit hook, we have to add our .mtimes.pickle file at the last second before commit
    #*GIT*#print(system('git', 'add', '-v', mtime_datafile))
    print(len(hashdic), 'mtime stamps saved')

def main():
    push_mtimes()
    sys.exit(0)

if __name__ == '__main__':
    main()
