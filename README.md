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

--
./run.sh