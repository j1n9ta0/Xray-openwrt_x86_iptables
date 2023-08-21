OpenWRT X86 软路由XRAY XTLS方式的透明代理

注：
当TCP数据进入12345端口后，会判断进入的是域名还是IP地址。
分流规则是IPIfNonMatch，优先匹配域名，如果在geosite查不到，就去DNS模块解析地址。
	国内域名，google-cn，apple-cn等域名直接从direct转发
	国外域名，geolocation-!cn从proxy转发
	其他域名，包括geosite里面没有匹配到的，和没有收录进来的域名，默认从direct转发。
XRAY的DNS模块只起根据ip分流作用。

为什么不需要劫持DNS请求就能访问geolocation-!cn的网站，例如google？
主要还是dokodemo-door中的sniffing功能，当接收到数据后，如果是geolocation-!cn的地址，使用proxy转发，就算DNS不正确也无所谓，XRAY会放到远程去处理，由于远程没有污染，所以顺利访问，并将结果返回。
这里的DNS组件，只起个分流作用，建议设置最快的服务器减少延迟，这里可以设置解析规则，将geolocation-!cn使用DOH解析以减少DNS泄露。
