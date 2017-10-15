# 防火墙规则
    New-NetFirewallRule -DisplayName "Block IPv6 Router Advertisement" -Protocol ICMPv6 -IcmpType 134 -Action Block
    Get-NetFirewallRule -DisplayName "Block IPv6 Router Advertisement"
    Remove-NetFirewallRule -DisplayName "RA Block"


# 路由
    New-NetRoute -AddressFamily IPv6 -DestinationPrefix "::/0" -InterfaceAlias 以太网 -NextHop "fe80::2a0:a50f:fc7d:bf00" -RouteMetric 0 -Confirm:$false
    New-NetRoute -AddressFamily IPv6 -DestinationPrefix "::/0" -InterfaceAlias 以太网 -NextHop "fe80::2a0:a50f:fc7d:bf01" -RouteMetric 0 -Confirm:$false
    Get-NetRoute -AddressFamily IPv6 -InterfaceAlias 以太网 -DestinationPrefix "::/0"
    Remove-NetRoute -AddressFamily IPv6 -DestinationPrefix "::/0" -Confirm:$false
    
# IP地址
    Get-NetIPAddress -InterfaceAlias 以太网|fl *
    Get-NetIPAddress -InterfaceAlias 以太网

    Remove-NetIPAddress -AddressFamily IPv6 -InterfaceAlias 以太网 -Confirm:$false
    New-NetIPAddress -AddressFamily IPv6 -Type Unicast -InterfaceIndex 17 "2001:da8:a800:af00::3b:e08a"

    $ethernet_ip_conf=Get-NetIPConfiguration -Detailed -InterfaceAlias 以太网
    $ethernet_ip_conf.IPv6Address

# DHCP 释放、刷新
    Start-Process ipconfig  -ArgumentList "/release6","以太网" -Wait -WindowStyle Hidden
    Start-Process ipconfig  -ArgumentList "/release","以太网"  -Wait -WindowStyle Hidden
    Start-Process ipconfig  -ArgumentList "/renew","以太网"    -Wait -WindowStyle Hidden
    Start-Process ipconfig  -ArgumentList "/renew6","以太网"   -Wait -WindowStyle Hidden
    ipconfig.exe /release 以太网
    ipconfig.exe /renew 以太网
    ipconfig.exe /renew6 以太网
    ipconfig.exe /release6 以太网

    Get-Process -Name ipconfig|Select-Object {$_.Kill()}

# 接口、适配器
    $ethernet=Get-NetAdapter -Name 以太网
    Get-NetAdapter -Name 以太网 |fl *
    $ethernet|fl -Property Name,LinkSpeed,MediaConnectionState
    $ether_adconf=Get-CimClass -Class Win32_NetworkAdapterConfiguration |? Index -eq 5


# 当前是否为寝室连接
    $default_ipv4_gw=Get-NetRoute -AddressFamily IPv4 -DestinationPrefix "0.0.0.0/0"|% NextHop
    $default_ipv4_gw -eq "192.168.35.1"

# 测试IPv6连接
    nslookup.exe /?
    nslookup.exe test-ipv6.comq


function is_dormitory_network_connected(){
    ((Get-NetAdapter -Name 以太网|% MediaConnectionState) -eq "Connected") -and
    ((Get-NetRoute -InterfaceAlias 以太网 -AddressFamily IPv4 -DestinationPrefix "0.0.0.0/0"|% NextHop) -eq "192.168.35.1")
}
function auto_connector () {
    $time_out_cnt=0
    while($true){
        $ping_result=Get-WmiObject -Query "select * from win32_pingstatus where Address='2607:8700:101:3118::' and Timeout=1000" -ErrorAction SilentlyContinue -ErrorVariable ping_error
        # $ping_error[0].CategoryInfo.Category.ToString() -eq "InvalidOperation"
        if($ping_error){
            Write-Host "ping error"
            New-NetRoute -AddressFamily IPv6 -DestinationPrefix "::/0" -InterfaceAlias 以太网 -NextHop "fe80::2a0:a50f:fc7d:bf00" -RouteMetric 0 -Confirm:$false -ErrorAction Ignore
            New-NetRoute -AddressFamily IPv6 -DestinationPrefix "::/0" -InterfaceAlias 以太网 -NextHop "fe80::2a0:a50f:fc7d:bf01" -RouteMetric 0 -Confirm:$false -ErrorAction Ignore
            Get-NetRoute -AddressFamily IPv6 -InterfaceAlias 以太网 -DestinationPrefix "::/0"
            continue
        }
        switch($ping_result.statuscode){
            0 {
                $time_out_cnt=0
                Start-Sleep -Seconds 2
            }
            11010 {
                $time_out_cnt++
                if($time_out_cnt -eq 3){
                    $time_out_cnt=0
                    Write-Host "连接超时"
                    if(-not(is_dormitory_network_connected)){
                        Write-Host "当前不是寝室网络，休眠5分钟"
                        Start-Sleep -Seconds 60
                        continue
                    }
                    Start-Process ipconfig -WindowStyle Hidden -ArgumentList "/renew6","以太网"
                    Start-Sleep -Seconds 5
                    Stop-Process -Name ipconfig -ErrorAction SilentlyContinue
                }else{
                    Start-Sleep -Milliseconds 500
                }
            }
            11003 {
                Write-Host "目标主机不可达"
                Start-Sleep -Seconds 5
            }
            11050 {
                Write-Host $ping_result.statuscode
                if(-not(is_dormitory_network_connected)){
                    Write-Host "当前不是寝室网络，休眠1分钟"
                    Start-Sleep -Seconds 60
                }
            }
            default {
                Write-Host $ping_result.statuscode
            }
        }
    }
}

auto_connector
    
