#!/usr/bin/env python3
"""Print packets from a specific IP/MAC
on a given interface or a pcap file."""
import sys
import argparse
import pyshark


def get_parser():
    parser = argparse.ArgumentParser(description='Learn about packets a host sends')
    parser.add_argument('--tcp', action='store_true', default=False, help='only show TCP packets')
    parser.add_argument('--udp', action='store_true', default=False, help='only show UDP packets')
    parser.add_argument('--sctp', action='store_true', default=False, help='only show SCTP packets')
    parser.add_argument('--timeout', type=int, default=None, help='stop listening after TIMEOUT seconds')
    subparsers = parser.add_subparsers(title='commands', dest='command')
    listen_parser = subparsers.add_parser('listen')
    listen_parser.add_argument('-i', '--interface', type=str, required=True, help='listening interface')
    listen_parser.add_argument('-t', '--target', type=str, required=True, help='target host IP address')
    listen_parser.add_argument('-e', '--ethernet', action='store_true', default=False, help='use MAC address instead of IP')
    parse_parser = subparsers.add_parser('parse')
    parse_parser.add_argument('-f', '--file', type=str, required=True, help='input file')
    parse_parser.add_argument('-t', '--target', type=str, required=True, help='target host IP address')
    parse_parser.add_argument('-e', '--ethernet', action='store_true', default=False, help='use MAC address instead of IP')
    return parser


class Observer(object):
    def __init__(self, args):
        self.args = args
        self.connections = {}
        if self.args.ethernet:
            self.display_filter = 'eth.src==' + self.args.target
        else:
            self.display_filter = 'ip.src==' + self.args.target

    def parse(self):
        """Parse packets from a pcap capture file."""
        capture = pyshark.FileCapture(self.args.file,
                                      display_filter=self.display_filter)
        self._apply_on_packets(capture)

    def listen(self):
        """Live capturing on a network interface."""
        capture = pyshark.LiveCapture(interface=self.args.interface,
                                      display_filter=self.display_filter)
        self._apply_on_packets(capture)

    def _apply_on_packets(self, capture):
        try:
            capture.apply_on_packets(self._packet_received_callback,
                                     timeout=self.args.timeout)
        except KeyboardInterrupt:
            pass

    def _packet_received_callback(self, packet):
        if len(packet.layers) > 2 and packet.layers[2].layer_name == 'tcp':
            if str(packet.layers[2].dstport) == '443':
                breakpoint()
        if len(packet.layers) is 2:
            # ethernet packet
            target = packet.highest_layer + ':' + packet.eth.dst
        else:
            if packet.transport_layer:
                if packet.layers[1].layer_name == 'ip':
                    target = packet.transport_layer + ':' + packet.ip.dst
                elif packet.layers[1].layer_name == 'ipv6':
                    target = packet.transport_layer + ':' + packet.ipv6.dst
                else:
                    print('Invalid layer: ', packet.layers[1].layer_name)
                    sys.exit(1)
                if packet.transport_layer == 'TCP' or \
                        packet.transport_layer == 'UDP' or \
                        packet.transport_layer == 'SCTP':
                    target += ':' + str(packet[packet.transport_layer].dstport)
            else:
                if packet.layers[1].layer_name == 'ip':
                    target = packet.highest_layer + ':' + packet.ip.dst
                elif packet.layers[1].layer_name == 'ipv6':
                    target = packet.highest_layer + ':' + packet.ipv6.dst
                else:
                    print('Invalid layer: ', packet.layers[1].layer_name)
                    sys.exit(1)
        if not target in self.connections.keys():
            self.connections[target] = packet
            self._pretty_print_packet(self._unpack_packet(packet))

    def _unpack_packet(self, packet):
        p = {}
        p['proto'] = packet.highest_layer
        if packet.layers[1].layer_name == 'ip':
            p['src_host'] = packet.ip.src
            p['dst_host'] = packet.ip.dst
            p['routing_layer'] = 'IP'
        elif packet.layers[1].layer_name == 'ipv6':
            p['src_host'] = packet.ipv6.src
            p['dst_host'] = packet.ipv6.dst
            p['routing_layer'] = 'IPv6'
        else:
            p['src_host'] = packet.eth.src
            p['dst_host'] = packet.eth.dst
        if packet.transport_layer:
            p['transport_layer'] = packet.transport_layer
            if p['transport_layer'] == 'TCP' or \
                    p['transport_layer'] == 'UDP' or \
                    p['transport_layer'] == 'SCTP':
                p['src_port'] = packet[packet.transport_layer].srcport
                p['dst_port'] = packet[packet.transport_layer].dstport
        return p

    def _pretty_print_packet(self, packet):
        f = '{proto} to {dst_host}'
        if packet.get('transport_layer') and \
                (packet['transport_layer'] == 'TCP' or \
                packet['transport_layer'] == 'UDP'):
            f += ':{dst_port} ({routing_layer}/{transport_layer})'
            print(f.format(transport_layer=packet['transport_layer'],
                        routing_layer=packet['routing_layer'],
                        proto=packet['proto'],
                        dst_host=packet['dst_host'],
                        dst_port=packet['dst_port']))
        else:
            print(f.format(proto=packet['proto'],
                           dst_host=packet['dst_host']))


if __name__ == '__main__':
    args = get_parser().parse_args()
    obs = Observer(args)
    if args.command == 'listen':
        obs.listen()
    elif args.command == 'parse':
        obs.parse()
    else:
        print('Invalid options')
        sys.exit(1)
