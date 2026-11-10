"""Read-only Linux disk inventory and explicit handoff to the system disk tool."""
import json
from pathlib import Path
import shutil
import stat
import sys
from PySide6.QtCore import QObject, Property, Signal, Slot, QProcess, QTimer

COLUMNS = 'NAME,PATH,TYPE,SIZE,MODEL,LABEL,FSTYPE,MOUNTPOINTS,FSUSED,FSAVAIL,FSSIZE,TRAN,RO,PTTYPE'
DEMO = {'blockdevices': [
    {'name':'/dev/nvme0n1','path':'/dev/nvme0n1','type':'disk','size':500107862016,'model':'Example NVMe SSD','tran':'nvme','pttype':'gpt','children':[
        {'name':'/dev/nvme0n1p1','path':'/dev/nvme0n1p1','type':'part','size':1073741824,'label':'EFI','fstype':'vfat'},
        {'name':'/dev/nvme0n1p2','path':'/dev/nvme0n1p2','type':'part','size':499034120192,'label':'makOS HD','fstype':'ext4','mountpoints':['/'],'fssize':489000000000,'fsused':32000000000,'fsavail':457000000000}]},
    {'name':'/dev/sdb','path':'/dev/sdb','type':'disk','size':128000000000,'model':'Example USB Drive','tran':'usb','pttype':'gpt','children':[
        {'name':'/dev/sdb1','path':'/dev/sdb1','type':'part','size':127998000000,'label':'Backup','fstype':'exfat','mountpoints':['/media/demo/Backup'],'fssize':127998000000,'fsused':25000000000,'fsavail':102998000000}]}]}


def size_text(value):
    if value is None: return 'Not available'
    amount=float(value)
    for suffix in ('B','KB','MB','GB','TB','PB'):
        if amount < 1000 or suffix == 'PB': return f'{amount:,.2f} {suffix}' if suffix != 'B' else f'{amount:.0f} B'
        amount /= 1000


def inventory(document):
    rows=[]
    def visit(node, depth=0, transport='', category='Internal', parent_table=''):
        path=node.get('path') or node.get('name') or ''
        if not path.startswith('/dev/') or '/..' in path: return
        transport=node.get('tran') or transport
        category='Disk Images' if node.get('type') in ('loop','rom') else ('External' if transport=='usb' else category)
        size=int(node.get('size') or 0)
        fs_size=node.get('fssize'); used=node.get('fsused'); available=node.get('fsavail')
        fs=node.get('fstype') or ''; table=node.get('pttype') or parent_table
        physical=node.get('type')=='disk'
        title=node.get('label') or (node.get('model') or '').strip() or Path(path).name
        kind='Physical Disk' if physical else 'Volume' if fs else (node.get('type') or 'Device').title()
        mounts=[x for x in (node.get('mountpoints') or []) if x]
        known=fs_size is not None and used is not None and int(fs_size)>0
        rows.append({'path':path,'title':title,'depth':depth,'category':category,'physical':physical,
            'subtitle':f'{transport.upper() or "Linux"} {kind}'+(' · '+fs.upper() if fs else ''),
            'capacity':size_text(size),'used':size_text(used),'available':size_text(available),
            'usageKnown':known,'fraction':min(1,max(0,int(used)/int(fs_size))) if known else 0,
            'format':fs.upper() or ('Partitioned disk' if physical and table else 'Not formatted'),'scheme':{'gpt':'GUID Partition Table','dos':'Master Boot Record'}.get(table,table or 'Not available'),
            'mount':', '.join(mounts) or 'Not mounted','transport':transport.upper() or 'Not available',
            'readOnly':bool(node.get('ro')),'kind':kind})
        for child in node.get('children') or []: visit(child,depth+1,transport,category,table)
    for device in document.get('blockdevices',[]): visit(device)
    return rows


class DiskInventory(QObject):
    changed=Signal()
    message=Signal(str,str)
    def __init__(self, preview=True, parent=None):
        super().__init__(parent); self._preview=preview or sys.platform!='linux';self._rows=[];self._busy=False;self._error='';self._process=None
    @Property('QVariantList',notify=changed)
    def rows(self): return self._rows
    @Property(bool,constant=True)
    def preview(self): return self._preview
    @Property(bool,notify=changed)
    def busy(self): return self._busy
    @Property(str,notify=changed)
    def error(self): return self._error
    @Slot()
    def refresh(self):
        if self._busy:return
        if self._preview:self._rows=inventory(DEMO);self.changed.emit();return
        executable=shutil.which('lsblk')
        if not executable:self._error='Disk information is unavailable: lsblk is missing.';self.changed.emit();return
        self._busy=True;self._error='';self.changed.emit()
        process=QProcess(self);self._process=process
        timer=QTimer(process);timer.setSingleShot(True);timer.setInterval(5000)
        timer.timeout.connect(process.kill)
        def complete(code=0,*_):
            if self._process is not process:return
            timer.stop();self._process=None;self._busy=False
            try:
                if code:raise ValueError('The disk scan did not complete. Try Refresh.')
                self._rows=inventory(json.loads(bytes(process.readAllStandardOutput())))
            except (ValueError,TypeError,KeyError) as error:self._error=str(error);self._rows=[]
            self.changed.emit();process.deleteLater()
        process.finished.connect(complete)
        process.errorOccurred.connect(lambda e:complete(1) if e==QProcess.ProcessError.FailedToStart else None)
        process.start(executable,['--json','--bytes','--paths','--tree','--output',COLUMNS]);timer.start()
    @Slot(str)
    def openDiskTools(self,path):
        if self._preview:self.message.emit('Disk Utility Preview','These example disks are only for the interface preview.');return
        if not any(row['path']==path for row in self._rows):return
        try:
            if not stat.S_ISBLK(Path(path).stat().st_mode):raise OSError('Device unavailable')
        except OSError:self.message.emit('Disk Unavailable','Refresh the disk list and select the device again.');return
        executable=shutil.which('gnome-disks')
        if not executable:self.message.emit('Disk Tools Unavailable','GNOME Disks is missing from this image.');return
        ok,_=QProcess.startDetached(executable,['--block-device',path])
        if not ok:self.message.emit('Unable to Open Disk Tools','The system disk utility could not be started.')
