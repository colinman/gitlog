Set up Redis
---
wget http://download.redis.io/redis-stable.tar.gz
tar xvzf redis-stable.tar.gz
cd redis-stable
make
make install
make test # just to make sure everything is good

Install Node Packages
---
npm install
npm install -g coffee-script

IMPORTANT: Make sure to change 'baseUrl' in index.coffee to match host name

Run
--
./run.sh