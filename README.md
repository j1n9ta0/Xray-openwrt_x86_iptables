# OpenWRT X86 软路由 XRAY XTLS 方式的透明代理

## 注：

当 TCP 数据进入 12345 端口后，会判断进入的是域名还是 IP 地址。

- 国内域名，google-cn，apple-cn 等域名直接从 direct 转发
- 国外域名，geolocation-!cn 从 proxy 转发
- 其他域名，包括 geosite 里面没有匹配到的，和没有收录进来的域名，默认从 direct 转发。
  XRAY 的 DNS 模块只起根据 ip 分流作用。

##### 为什么不需要劫持 DNS 请求就能访问 geolocation-!cn 的网站，例如 google？

主要还是 dokodemo-door 中的 sniffing 功能，当接收到数据后，如果是 geolocation-!cn 的地址，使用 proxy 转发，就算 DNS 不正确也无所谓，XRAY 会放到远程去处理，由于远程没有污染，所以顺利访问，并将结果返回。
这里的 DNS 组件，只起个分流作用，建议设置最快的服务器减少延迟，这里可以设置解析规则，将 geolocation-!cn 使用 DOH 解析以减少 DNS 泄露。
