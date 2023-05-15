# yala
Yala is just Yet Another Log Analyzer.  It focuses on providing quick JBoss EAP 7+ server log summaries, highlighting known critical ERRORs, and counts of other general errors at a glance.

# installation
* To install, run the following in a directory where you want to keep the script and known error file references:
```
wget https://raw.githubusercontent.com/aogburn/yala/main/yala.sh
chmod 755 yala.sh
wget https://raw.githubusercontent.com/aogburn/yala/master/yala-errors.tar.xz
tar -xf yala-errors.tar.xz
```

# updating 

When run, yala will look for a new version to use and update itself with a simple wget if so.  Uncomment the CHECK_UPDATE flag in the script if you need to disable those update checks. The script may be updated over time with new helpful checks, stats, or known issue searches.

# usage

* To run:
```
 ./yala.sh server.log
```
* Options:
```
 -l, --last              analyse the last started JBoss only
 -s, --skip              skip checking for updates
 -h, --help              show this help
```
