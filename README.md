# DocumentDB Proxy

DocumentDB Proxy is a prototype implementation of a reverse proxy for access control to RESTful document-oriented databases. It uses Sinatra and HTTParty to implement reverse proxy. Currently, it assumes to be used with mod\_passenger and mod\_auth\_openidc but it could be used with the other middleware (requires testing). The aim of this project is providing a template of thin access control logic layer on server side. We hope that it will help exploiting document-oriented databases more easily without implementing own URI routing for highly functional DB's RESTful APIs.

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


## How to customize access control logic

```
cd /var/www/webapps/document-db-proxy
vi my_proxy.rb
```
```
require './elasticsearch'

class MyProxy < Elasticsearch
  # override condition logic
  def authorized?(username)
    ...
  end

  # 
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
