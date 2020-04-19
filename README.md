# DocumentDB Proxy

DocumentDB Proxy is a prototype implementation of a reverse proxy for access control to RESTful document-oriented databases. It uses Sinatra and HTTParty to implement reverse proxy. Currently, it assumes to be used with mod\_passenger and mod\_auth\_openidc but it could be used with the other middleware (requires testing). The aim of this project is providing a template of thin access control logic layer on server side. We hope that it will help exploiting document-oriented databases more easily without implementing own URI routing for highly functional DB's RESTful APIs.

The current implementation does not consider the execution performance of access control logic. It should be improved before deploying to the production environment.


## Install

An example installation of DocumentDB Proxy into mod_passenger environment (Apache HTTPD).

```
vi ssl.conf
```
```
<VirtualHost _default_:443>
DocumentRoot "/var/www/webapps/document-db-proxy/public"
ServerName apache.localdomain:443

...
<Directory "/var/www/webapps/document-db-proxy/public">
  Require all granted
  Allow from all
  Options -MultiViews
</Directory>
```

```
cd /var/www/webapps
git clone https://github.com/toyokazu/document-db-proxy.git
```


## Assumed schema in the template implementation

The template implementation (Elasticsearch) assumes ownership base access control which assumes that each document has an owner attribute and user id is provided by a SSO platform, e.g. OpenID Connect. The default configuration parameter uses "username" as an owner attribute and "OIC_CLAIM_preferred_username" as a user id provided by SSO platform. The followings are example mappings of Elasticsearch.

```
vi running-data.json
```
```
{
  "mappings": {
    "properties": {
      "username": { "type": "keyword" },
      "location": { "type": "geo_point" },
      "heart_rate": { "type": "integer" },
      "timestamp": { "type": "date", "format": "yyyy-MM-dd HH:mm:ss||yyyy-MM-dd||epoch_millis" },
    }
  }
}
```
```
curl -d @running-data.json -H "Content-Type: application/json" -XPUT http://localhost:9200/running-data
vi running-data-sample.json
```
```
{ "index": {}  }
{ "username": "john", "location": { "lat": "38.8976763", "lon": "-77.0387238" }, "heart_rate": "60", "timestamp": "2020-04-20 00:00:00.000" }
{ "index": {}  }
{ "username": "ken", "location": { "lat": "38.8976763", "lon": "-77.0387238" }, "heart_rate": "60", "timestamp": "2020-04-20 01:00:00.000" }
{ "index": {}  }
{ "username": "mary", "location": { "lat": "38.8976763", "lon": "-77.0387238" }, "heart_rate": "60", "timestamp": "2020-04-20 02:00:00.000" }
{ "index": {}  }
{ "username": "alice", "location": { "lat": "38.8976763", "lon": "-77.0387238" }, "heart_rate": "60", "timestamp": "2020-04-20 03:00:00.000" }
{ "index": {}  }
{ "username": "bob", "location": { "lat": "38.8976763", "lon": "-77.0387238" }, "heart_rate": "60", "timestamp": "2020-04-20 04:00:00.000" }
```

```
curl --data-binary @running-data-sample.json -H "Content-Type: application/x-ndjson" -XPOST http://localhost:9200/running-data/_bulk?pretty
vi teams.json
```
```
{
  "mappings": {
    "properties": {
      "teamname": { "type": "keyword" },
      "members": { "type": "keyword" },
      "timestamp": { "type": "date", "format": "yyyy-MM-dd HH:mm:ss||yyyy-MM-dd HH:mm:ss.SSS||yyyy-MM-dd||epoch_millis" },
    }
  }
}
```
```
curl -d @teams.json -H "Content-Type: application/json" -XPUT http://localhost:9200/teams
vi teams-data-sample.json
```
```
{ "index": {}  }
{ "teamname": "team1", "members": ["john", "mary"], "timestamp": "2020-04-20 00:00:00.000" }
{ "index": {}  }
{ "teamname": "team2", "members": ["ken", "bob"], "timestamp": "2020-04-20 01:00:00.000" }
{ "index": {}  }
{ "teamname": "team3", "members": ["alice", "john"], "timestamp": "2020-04-20 02:00:00.000" }
```
```
curl --data-binary @teams-data-sample.json -H "Content-Type: application/x-ndjson" -XPOST http://localhost:9200/teams/_bulk?pretty
```


## How to customize access control logic

```
cd /var/www/webapps/document-db-proxy
vi my_proxy.rb
```
```
require './elasticsearch'

class MyProxy < Elasticsearch
  # override configuration parameters
  configure do
    ...
  end

  # override condition logic
  def authorized?(username)
    ...
  end

  def add_condition(body)
    ...
  end 
end
```

```
vi config.ru
```
```
require './my_proxy'
run MyProxy
```

If you like sub URI, use map method (provided by sinatra).


```
vi config.ru
```
```
require './my_proxy'
map('/elasticsearch') { run MyProxy }
```


## Contributing

Currently, Elasticsearch is the only database supported by this proxy. If you interested in contributing this project, please implement a new class based on the code elasticsearch.rb and make a pull request.

1. Fork it ( http://github.com/toyokazu/document-db-proxy/fork )
2. Create your feature branch (git checkout -b my-new-feature)
3. Commit your changes (git commit -am 'Add some feature')
4. Push to the branch (git push origin my-new-feature)
5. Create new Pull Request
