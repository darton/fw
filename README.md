
Skrypt fw.sh konfiguruje system linuxowy do pracy jako zapora (firewall) pobierając konfigurację z LMS (http://lms.org.pl) 

#### GATEWAY ####

Maszyna zwana GATEWAY pełni funkcję rutera/shapera, na której pracuje skrypt fw.sh, konieczne jest ustawienie w crontab odpowiednich wpisów:

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


