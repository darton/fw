fw.sh

Skrypt fw.sh konfiguruje system linuxowy do pracy jako zapora (firewall) i/lub shaper pobierając swoją konfigurację z plików generowanych przez odpowiednio skonfigurowane instancje LMS (http://lms.org.pl) lub dowolny inny program, można też pliki konfiguracyjne stworzyć ręcznie lub skryptem w bash.

Np plik z adresami ip które mają być natowane na adres ip powinien mieć nazwę np fw_nat_ip1
a jego zawartość np:

grantedhost 192.168.102.96 </br>
deniedhost 192.168.102.99
grantedhost 192.168.102.101
grantedhost 192.168.102.105
grantedhost 192.168.102.108
grantedhost 192.168.102.110
deniedhost 192.168.102.112
grantedhost 192.168.102.118
grantedhost 192.168.102.134
grantedhost 192.168.102.147
grantedhost 192.168.102.151
grantedhost 192.168.102.153

Jeśli mamy wiele adresów ip na ktore chemy natować  w systemie jeden do wielu np cztery adresy ip, tworzymy osobne pliki dla nich np.: 
fw_nat_ip1 fw_nat_ip2 fw_nat_ip3 fw_nat_ip4 i do każdego wrzucami listę adresów ip hostów wraz z ich statusami (denied| granted)
W pliku fw_nat_1-n zapisujemy powiązania pomiędzy tymi plikami a adresami ip na które ma odbywać się natowanie
 
Przykładowa  zawrtość pliku fw_nat_1-n
 
fw_nat_ip1 172.16.0.1
fw_nat_ip2 172.16.0.111
fw_nat_ip3 172.16.0.222
fw_nat_ip4 172.16.0.253

Wtedy wszystkie adresy op jakie zawiera plik fw_nat_ip1 bedą natowane na adres 172.16.0.1, zaś wszystkie adresy ip zawarte w pliku  
fw_nat_ipe będą natowane na adres ip 172.16.0.111 ... itd.

Nazwy plików mogą być dowolne trzeba je tylko zadeklarować w pliku fw.sh oraz fw_nat_1-n.
W przykładzie opisane są nazwy jakie są skonfigurowane domyśłnie.



W celu optymalnej wydajności przetwarzania pakietów, korzysta z ipset.

Skrypt posiada mechanizm pozwalający na unikanie, kiedy tylko to możliwe niepotrzebnego przeładowania reguł iptables, korzystając z mechanizmu podmiany gotowych list ipset. 

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

fw_public_ip	#Zawiera listę hostów z publicznymi adresami IP w formacie: "grantedhost|deniedhost|warnedhost adres_ip"

fw_nat_1-1	#Zawiera listę hostów z prywatnymi adresami IP natowanymi 1-1 na adresy publiczne w formacie: "grantedhost|deniedhost|warnedhost prywatny_adres_ip publiczny_adres_ip"

fw_nat_1-n	#Zawiera listę w formacie: "nazwa_pliku publiczny_adres_ip", opisującego powiązania plików z prywatnymi adresami IP i odpowiadającymi im publicznymi adresami IP na które będą NAT-owane

fw_lan_banned_dst_ports		#Zawiera listę portów TCP/IP w formacie: "numer_portu"

rc.htb		#Zawiera gotowy do uruchomienia skrypt shapera z regułami tc dla wszystkich hostów

dhcpd.conf	#Zawiera gotowy plik konfiguracyjny dla serwera dhcp


