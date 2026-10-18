#!/usr/bin/env python3
"""fakebluez.py BUS_ADDRESS [adapter] — a stand-in bluetoothd on a private bus: org.bluez
with an ObjectManager and an AgentManager1 that accepts an agent. Without "adapter" it lists
no adapters (bluetui's "no adapters" screen); with it, one powered adapter hci0 holding a
paired game controller and a paired headset, and one unpaired phone found nearby."""
import asyncio, sys
from dbus_next.aio import MessageBus
from dbus_next.service import ServiceInterface, method, dbus_property
from dbus_next import BusType, Variant, PropertyAccess

WITH_ADAPTER = len(sys.argv) > 2


class ObjectManager(ServiceInterface):
    def __init__(self, objects):
        super().__init__("org.freedesktop.DBus.ObjectManager")
        self.objects = objects

    @method()
    def GetManagedObjects(self) -> "a{oa{sa{sv}}}":
        return self.objects


class AgentManager(ServiceInterface):
    def __init__(self):
        super().__init__("org.bluez.AgentManager1")

    @method()
    def RegisterAgent(self, agent: "o", capability: "s"):
        print("agent registered:", agent, capability, flush=True)

    @method()
    def UnregisterAgent(self, agent: "o"):
        pass

    @method()
    def RequestDefaultAgent(self, agent: "o"):
        pass


def props(d):
    return {k: Variant(s, v) for k, (s, v) in d.items()}


class Adapter(ServiceInterface):
    def __init__(self):
        super().__init__("org.bluez.Adapter1")

    @dbus_property(access=PropertyAccess.READ)
    def Address(self) -> "s": return "AC:80:0A:00:00:01"
    @dbus_property(access=PropertyAccess.READ)
    def Name(self) -> "s": return "fedokawaii"
    @dbus_property()
    def Alias(self) -> "s": return "fedokawaii"
    @Alias.setter
    def Alias(self, v: "s"): pass
    @dbus_property()
    def Powered(self) -> "b": return True
    @Powered.setter
    def Powered(self, v: "b"): pass
    @dbus_property()
    def Discoverable(self) -> "b": return False
    @Discoverable.setter
    def Discoverable(self, v: "b"): pass
    @dbus_property()
    def Pairable(self) -> "b": return True
    @Pairable.setter
    def Pairable(self, v: "b"): pass
    @dbus_property(access=PropertyAccess.READ)
    def Discovering(self) -> "b": return False
    @dbus_property(access=PropertyAccess.READ)
    def UUIDs(self) -> "as": return []
    @method()
    def StartDiscovery(self): pass
    @method()
    def StopDiscovery(self): pass
    @method()
    def SetDiscoveryFilter(self, f: "a{sv}"): pass


class Device(ServiceInterface):
    def __init__(self, addr, name, icon, paired, trusted, connected):
        super().__init__("org.bluez.Device1")
        self.v = dict(addr=addr, name=name, icon=icon, paired=paired, trusted=trusted, connected=connected)

    @dbus_property(access=PropertyAccess.READ)
    def Address(self) -> "s": return self.v["addr"]
    @dbus_property(access=PropertyAccess.READ)
    def Name(self) -> "s": return self.v["name"]
    @dbus_property()
    def Alias(self) -> "s": return self.v["name"]
    @Alias.setter
    def Alias(self, v: "s"): pass
    @dbus_property(access=PropertyAccess.READ)
    def Icon(self) -> "s": return self.v["icon"]
    @dbus_property(access=PropertyAccess.READ)
    def Paired(self) -> "b": return self.v["paired"]
    @dbus_property(access=PropertyAccess.READ)
    def Bonded(self) -> "b": return self.v["paired"]
    @dbus_property()
    def Trusted(self) -> "b": return self.v["trusted"]
    @Trusted.setter
    def Trusted(self, v: "b"): pass
    @dbus_property()
    def Blocked(self) -> "b": return False
    @Blocked.setter
    def Blocked(self, v: "b"): pass
    @dbus_property(access=PropertyAccess.READ)
    def Connected(self) -> "b": return self.v["connected"]
    @dbus_property(access=PropertyAccess.READ)
    def Adapter(self) -> "o": return "/org/bluez/hci0"
    @dbus_property(access=PropertyAccess.READ)
    def LegacyPairing(self) -> "b": return False
    @dbus_property(access=PropertyAccess.READ)
    def ServicesResolved(self) -> "b": return self.v["connected"]
    @dbus_property(access=PropertyAccess.READ)
    def UUIDs(self) -> "as": return []
    @dbus_property(access=PropertyAccess.READ)
    def RSSI(self) -> "n": return -60


class Battery(ServiceInterface):
    def __init__(self, pct):
        super().__init__("org.bluez.Battery1"); self.pct = pct

    @dbus_property(access=PropertyAccess.READ)
    def Percentage(self) -> "y": return self.pct


DEVICES = [("/org/bluez/hci0/dev_E4_17_D8_11_22_33", "E4:17:D8:11:22:33", "Xbox Wireless Controller", "input-gaming", True, True, True),
           ("/org/bluez/hci0/dev_AC_80_0A_12_34_56", "AC:80:0A:12:34:56", "WH-1000XM4", "audio-headset", True, True, False),
           ("/org/bluez/hci0/dev_00_11_22_33_44_55", "00:11:22:33:44:55", "Fluvia's phone", "phone", False, False, False)]


async def main():
    bus = await MessageBus(bus_address=sys.argv[1], bus_type=BusType.SYSTEM).connect()
    objects = {}
    if WITH_ADAPTER:
        a = Adapter(); bus.export("/org/bluez/hci0", a)
        objects["/org/bluez/hci0"] = {"org.bluez.Adapter1": props({
            "Address": ("s", "AC:80:0A:00:00:01"), "Name": ("s", "fedokawaii"), "Alias": ("s", "fedokawaii"),
            "Powered": ("b", True), "Discoverable": ("b", False), "Pairable": ("b", True),
            "Discovering": ("b", False), "UUIDs": ("as", [])})}
        for path, addr, name, icon, paired, trusted, connected in DEVICES:
            bus.export(path, Device(addr, name, icon, paired, trusted, connected)); bus.export(path, Battery(72))
            objects[path] = {"org.bluez.Device1": props({
                "Address": ("s", addr), "Name": ("s", name), "Alias": ("s", name), "Icon": ("s", icon),
                "Paired": ("b", paired), "Bonded": ("b", paired), "Trusted": ("b", trusted), "Blocked": ("b", False),
                "Connected": ("b", connected), "Adapter": ("o", "/org/bluez/hci0"), "LegacyPairing": ("b", False),
                "ServicesResolved": ("b", connected), "UUIDs": ("as", []), "RSSI": ("n", -60)}),
                "org.bluez.Battery1": props({"Percentage": ("y", 72)})}
    bus.export("/", ObjectManager(objects))
    bus.export("/org/bluez", AgentManager())
    await bus.request_name("org.bluez")
    print("fake org.bluez up", "with an adapter" if WITH_ADAPTER else "without an adapter", flush=True)
    await asyncio.get_event_loop().create_future()


asyncio.run(main())
