#!/usr/bin/env python3
import asyncio
import logging
import argparse
from asyncio import StreamReader, StreamWriter
from collections import namedtuple

logger = logging.getLogger()
logger.addHandler(logging.StreamHandler())
logger.setLevel(logging.INFO)


class HostAndPort(namedtuple('_', 'host port')):
    @classmethod
    def from_string(cls, x: str):
        host, port = x.rsplit(':', 1)
        return cls(host, port)


def get_parser():
    parser = argparse.ArgumentParser(description='Tunnel connections via HTTP proxy')
    parser.add_argument('--listen', type=HostAndPort.from_string, required=True, help='listen address')
    parser.add_argument('--proxy', type=HostAndPort.from_string, required=True, help='address of the HTTP proxy server')
    parser.add_argument('--dest', type=HostAndPort.from_string, required=True, help='destination host')
    parser.add_argument('--timeout', type=int, default=300)
    parser.add_argument('--buffer-size', type=int, default=1024)
    return parser


async def proxy_data(reader, writer):
    try:
        while True:
            data = await asyncio.wait_for(reader.read(args.buffer_size),
                                          args.timeout)
            if not data:
                break
            writer.write(data)
            await asyncio.wait_for(writer.drain(), args.timeout)
    except Exception as e:
        logger.error('proxy_data_task exception {}'.format(e))
    finally:
        writer.close()
        logger.debug('close connection')


class ProxyHandler:
    def __init__(self, args):
        self.args = args

    async def handle(self, reader: StreamReader, writer: StreamWriter):
        dest = self.args.dest
        proxy = self.args.proxy
        (dst_reader, dst_writer) = await asyncio.open_connection(
            host=proxy.host, port=proxy.port)
        connect_req = 'CONNECT {host}:{port} '.format(host=dest.host,
                                                      port=dest.port)
        connect_req += 'HTTP/1.1\r\n\r\n'
        dst_writer.write(connect_req.encode())
        await dst_writer.drain()
        resp = await dst_reader.read(64)
        if not b'200' in resp:
            logger.error('Proxy connection failed: ' + resp.decode())
            return
        await asyncio.wait([asyncio.ensure_future(proxy_data(reader, dst_writer)),
                            asyncio.ensure_future(proxy_data(dst_reader, writer))])


if __name__ == '__main__':
    try:
        import uvloop
        logger.info('Using uvloop.')
    except ImportError:
        logger.warning('uvloop not found.')
    else:
        asyncio.set_event_loop_policy(uvloop.EventLoopPolicy())
    loop = asyncio.get_event_loop()
    args = get_parser().parse_args()
    handler = ProxyHandler(args)
    server_coro = asyncio.start_server(handler.handle,
                                       host=args.listen.host,
                                       port=args.listen.port)
    server_task = loop.run_until_complete(server_coro)
    try:
        loop.run_forever()
    except KeyboardInterrupt:
        pass
