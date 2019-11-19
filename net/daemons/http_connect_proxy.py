import sys

from twisted.web import proxy, http
from twisted.internet import reactor

class ProxyFactory(http.HTTPFactory):
    def buildProtocol(self, addr):
        return proxy.Proxy()

try:
    port = int(sys.argv[0])
except Exception as e:
    print('Please provide a valid port number')
    print('Example: {} 8080'.format(sys.argv[0]))
    sys.exit(1)
reactor.listenTCP(port, ProxyFactory())
reactor.run()
