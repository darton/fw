fw.sh

Skrypt fw.sh konfiguruje system linuxowy do pracy jako zapora (firewall) i/lub shaper pobierając swoją konfigurację z plików generowanych przez odpowiednio skonfigurowane instancje LMS (http://lms.org.pl) lub dowolny inny program, można też pliki konfiguracyjne stworzyć ręcznie lub w dowolnym języku skryptowym bash/python/power_shell itd.

Przygotowanie konfiguracji dla skryptu jest banalne.
Np plik z adresami IP które mają być natowane na inny adres IP powinien mieć nazwę np. fw_nat_ip1
a jego zawartość powinna wygladać np tak:

grantedhost 192.168.102.96 </br>
deniedhost 192.168.102.99 </br>
grantedhost 192.168.102.101 </br>
grantedhost 192.168.102.105 </br>
grantedhost 192.168.102.108 </br>
grantedhost 192.168.102.110 </br>
deniedhost 192.168.102.112 </br>
grantedhost 192.168.102.118 </br>
grantedhost 192.168.102.134 </br>
grantedhost 192.168.102.147 </br>
grantedhost 192.168.102.151 </br>
grantedhost 192.168.102.153 </br>

Jeśli mamy wiele adresów ip na ktore chemy natować  w systemie jeden do wielu np cztery adresy ip, tworzymy osobne pliki dla nich np.: 
fw_nat_ip1, fw_nat_ip2, fw_nat_ip3, fw_nat_ip4. Do każdego pliku wrzucami listę adresów IP hostów wraz z ich statusami (denied| granted)
W pliku fw_nat_1-n zapisujemy powiązania pomiędzy tymi plikami a adresami IP na które ma odbywać się natowanie.
 
Przykładowa  zawrtość pliku fw_nat_1-n:
 
fw_nat_ip1 172.16.0.1 </br>
fw_nat_ip2 172.16.0.111 </br>
fw_nat_ip3 172.16.0.222 </br>
fw_nat_ip4 172.16.0.253 </br>

Wtedy wszystkie adresy IP jakie zawiera plik fw_nat_ip1 bedą natowane na adres 172.16.0.1, zaś wszystkie adresy IP zawarte w pliku  
fw_nat_ip2 będą natowane na adres IP 172.16.0.111 ... itd.

Nazwy plików mogą być dowolne trzeba je tylko zadeklarować w pliku fw.sh oraz fw_nat_1-n.
W przykładzie opisane są nazwy jakie są skonfigurowane domyślnie.

Plik fw_public_ip służy do prowadzenia rejestru adresów IP które mają beć rutowane (bez NAT)
w formacie analogicznym jak dla adresów Natowanych czyli

grantedhost 192.168.102.96 </br>
deniedhost 192.168.102.99 </br>
grantedhost 192.168.102.101 </br>
grantedhost 192.168.102.105 </br>

Plik fw_routed_ip służy to prowadzenia rejestru sieci oraz adresów IP bramek (gateway) na które te sieci mają być rutowane w formacie:
Sieć/prefiks adres_IP_bramki

172.16.0.128/30 172.16.1.7 </br>
172.16.1.128/30 172.16.1.8 </br>
172.16.3.128/30 172.16.1.9 </br>

Domyślnie skrypt pobiera swoje pliki konfiguracyjne łącząc się ze zdalną maszyną na której są tworzone za pomocą ssh z wykorzystaniem pary kluczy RSA. Jeśli pliki są tworzone lokalnie na tej samej maszynie na ktorej pracuje skrypt najprościej jest podać w konfiguracji adres IP 127.0.0.1. 

W celu optymalnej wydajności przetwarzania pakietów fw.sh korzysta z ipset. To pozwala na wykorzystanie go w sieciach z tysiącami komputerów.

Skrypt posiada mechanizm pozwalający na unikanie, kiedy tylko to możliwe niepotrzebnego przeładowania reguł iptables, korzystając z mechanizmu podmiany gotowych list ipset podczas którego transmisja pakietów nie ulega przerwaniu. 

Odczytuje także cyklicznie stany liczników pakietów i ładuje je do tabeli stats bazy danych LMS, co pozwala na generowanie statystyk ruchu dla klientów. 

### Gateway ###

Na maszynie na której pracuje skrypt fw.sh, konieczne jest ustawienie w crontab odpowiednich wpisów:

Wpis uruchamiający skrypt fw.sh z parametrem lmsd, który sprawdza co minutę status przeładowania w LMS. W przypadku jego ustawienia przez operatora LMS pobiera konfigurację z LMS i przeładowywuje firewall

* * * * * /opt/gateway/scripts/fw.sh lmsd

Wpisy uruchamiające skrypt fw.sh z parametrem qos, które przełączają shaper na taryfę nocną.

01 22 * * * /opt/gateway/scripts/fw.sh qos

01 10 * * * /opt/gateway/scripts/fw.sh qos



#### LMS ####

Na maszynie z zainstalowanym LMS należy uruchamiać cyklicznie np co 5 minut skrypt zapisujący statystyki do bazy danych LMS, wykonujący polecenia:

ssh -p 222 root@192.168.100.1 '/opt/gateway/scripts/fw.sh stats' > /var/log/traffic.log

Polecenie to uruchomi zdalnie na maszynie GATEWAY skrypt fw.sh z parametrem stats, który odczyta liczniki przesłanych danych dla wszystkich hostów i zapisze je do pliku.


bash /var/www/html/lms/bin/lms-traffic

Skrypt ten odczyta plik /var/log/traffic.log i zapisze wartości do tabeli stats w bazie danych LMS.

 
### Opis konfiguracji LMS ###

Poniższe pliki konfiguracyjne dla skryptu fw.sh powinny być generowane przez lmsd uruchomionego na maszynie z LMS:

fw_public_ip </br>
Zawiera listę hostów z publicznymi adresami IP w formacie: "grantedhost|deniedhost|warnedhost adres_ip"

fw_nat_1-1	</br>
Zawiera listę hostów z prywatnymi adresami IP natowanymi 1-1 na adresy publiczne w formacie: "grantedhost|deniedhost|warnedhost prywatny_adres_ip publiczny_adres_ip"

fw_nat_1-n	</br>
Zawiera listę w formacie: "nazwa_pliku publiczny_adres_ip", opisującego powiązania plików z prywatnymi adresami IP i odpowiadającymi im publicznymi adresami IP na które będą NAT-owane

fw_lan_banned_dst_ports </br>
Zawiera listę portów TCP/IP w formacie: "numer_portu"

rc.htb </br>
Zawiera gotowy do uruchomienia skrypt shapera z regułami tc dla wszystkich hostów

dhcpd.conf </br>
Zawiera gotowy plik konfiguracyjny dla serwera dhcp


