
Skrypt fw.sh konfiguruje system linuxowy do pracy jako zapora (firewall) i/lub shaper pobierając swoją konfigurację z plików generowanych przez odpowiednio skonfigurowane instancje LMS (http://lms.org.pl) lub dowolny inny program, można też pliki konfiguracyjne stworzyć ręcznie.

# Instalacja

#curl -sS https://raw.githubusercontent.com/darton/fw/master/install.sh |bash

# Sposób użycia

 /opt/gateway/scripts/fw.sh </br>
Usage: fw.sh start|stop|restart|reload|stats|lmsd|qos|status|maintenance-on|maintenance-off

# Przygotowanie plików konfiguracyjnych dla skryptu

Konieczne do uruchomienia skryptu pliki konfiguracyjne (domyślnie puste):

fw_public_ip </br>
Zawiera listę hostów z publicznymi adresami IP w formacie: "grantedhost|deniedhost|warnedhost adres_ip"

fw_nat_1-1	</br>
Zawiera listę hostów z prywatnymi adresami IP natowanymi 1-1 na adresy publiczne w formacie: "grantedhost|deniedhost|warnedhost prywatny_adres_ip publiczny_adres_ip"

fw_nat_1-n	</br>
Zawiera listę w formacie: "nazwa_pliku_z_lista_adresów_IP publiczny_adres_ip", opisującego powiązania plików z prywatnymi adresami IP i odpowiadającymi im publicznymi adresami IP na które będą NAT-owane

fw_lan_banned_dst_ports </br>
Zawiera listę portów TCP/IP w formacie: "numer_portu"

rc.htb </br>
Zawiera gotowy do uruchomienia skrypt shapera z regułami tc dla wszystkich hostów

dhcpd.conf </br>
Zawiera gotowy plik konfiguracyjny dla serwera dhcp

Np. plik z adresami IP, które mają być natowane na inny adres IP powinien mieć nazwę np. fw_nat_ip1
a jego zawartość powinna wygladać np tak:

grantedhost 192.168.102.96 </br>
deniedhost 192.168.102.99 </br>

Jeśli mamy wiele adresów ip na które chemy natować  w systemie jeden do wielu np. cztery adresy ip, tworzymy osobne pliki dla nich np.: 
fw_nat_ip1, fw_nat_ip2, fw_nat_ip3, fw_nat_ip4. Do każdego pliku wrzucamy listę adresów IP hostów wraz z ich statusami (denied| granted)
W pliku fw_nat_1-n zapisujemy powiązania pomiędzy tymi plikami a adresami IP, na które ma odbywać się natowanie.
 
Przykładowa  zawrtość pliku fw_nat_1-n:
 
fw_nat_ip1 172.16.0.1 </br>
fw_nat_ip2 172.16.0.111 </br>
fw_nat_ip3 172.16.0.222 </br>
fw_nat_ip4 172.16.0.253 </br>

Wtedy wszystkie adresy IP jakie zawiera plik fw_nat_ip1 bedą natowane na adres 172.16.0.1, zaś wszystkie adresy IP zawarte w pliku fw_nat_ip2 będą natowane na adres IP 172.16.0.111 ... itd.

Nazwy plików mogą być dowolne trzeba je tylko zadeklarować w pliku fw.sh oraz fw_nat_1-n.
W przykładzie opisane są nazwy jakie są skonfigurowane domyślnie.

Plik fw_public_ip służy do prowadzenia rejestru adresów IP które mają beć rutowane (bez NAT)
w formacie analogicznym jak dla adresów Natowanych czyli

grantedhost 192.168.102.101 </br>
grantedhost 192.168.102.105 </br>

Plik fw_routed_ip służy to prowadzenia rejestru sieci oraz adresów IP bramek (gateway) na które te sieci mają być rutowane w formacie:
Sieć/prefiks adres_IP_bramki

172.16.0.128/30 172.16.1.7 </br>
172.16.1.128/30 172.16.1.8 </br>
172.16.3.128/30 172.16.1.9 </br>

Domyślnie skrypt pobiera swoje pliki konfiguracyjne łącząc się przez ssh ze zdalną maszyną, na której są tworzone. 
Dla łączenia przez ssh najlepiej użyć pary kluczy RSA. 
Jeśli pliki są tworzone lokalnie na tej samej maszynie, na ktorej pracuje skrypt najprościej jest podać w konfiguracji adres IP 127.0.0.1. 

W celu optymalnej wydajności przetwarzania pakietów fw.sh korzysta z ipset. To pozwala na wykorzystanie go w sieciach z tysiącami komputerów.

Skrypt posiada mechanizm pozwalający na unikanie, kiedy tylko to możliwe, niepotrzebnego przeładowania reguł iptables, korzystając z mechanizmu podmiany gotowych list ipset, podczas którego transmisja pakietów nie ulega przerwaniu. 

Odczytuje także cyklicznie stany liczników pakietów i ładuje je do pliku, Lms posiada skrypty (np lms-traffic) które pozwalają parsować taki plik i wrzucać z niego dane do tabeli stats swojej bazy danych, co pozwala na generowanie statystyk ruchu dla klientów. 

Gdy już mamy gotowe pliki konfiguracyjne uruchamiamy zaporę wykonuja skrypt z opcją: </br>

# fw.sh start </br>
Polecenie fw.sh start uruchomi zaporę odczytując parametry konfiguracyjne zawarte w plikach konfiguracyjncyh, dokana restartu serwera DHCP oraz reguł shapera.

# fw.sh stop </br>
Wykonanie fw.sh stop zatrzyma zaporę, wyłączy forwardowanie pakietów, włączy domyśłne polityki dla iptables (np FORWARD DENY).

# fw.sh restart </br>
wykona fw.sh start a potem ./fw stop czyli usunie wszystkie reguły iptables oraz ipset i utworzy je na nowo, powoduje to zerwanie wszystkich połączeń i przerę w transmisji na kilka sekund.

# fw.sh reload </br> 
wykona zmiany tylko tych reguł iptables, które się zmieniły: czyli np. usunie lub doda konkretną regułę iptables, lub podmieni tablice ipset. Aby uniknąć przerw w transmisji pakietów odczuwalnych dla wszystkich użytkowników należy korzystać właśnie z opcji reload przy wprowadzaniu zmian.

# fw.sh lmsd
Ten moduł służy do wspólpracy z LMS (http://lms.org.pl). Nasz router/firewall może wtedy pracować w sposób automatyczny.
Sterowanie fw.sh odbywa się wtedy z poziomu LMS. fw.sh  sprawdzi czy w LMS został ustawiony przez operatora status przeładowania danego hosta i wykona przeładowanie lub restart w zależności, które pliki konfiguracyjne i co w nich zostało zmienione. Jeśli pliki nie zostały zmienione, a w LMS został ustawiony status przeładowania, skrypt to wykryje, zmieni status przeładowania w LMS na wykonane,  ale nie wykona restartu/przeładowania, zapisze tylko informacje w logach.

Po instalacji ./fw.sh lmsd jest uruchamiany co minutę przez cron.
uruchamianie fw.sh z modułem lmsd wymaga odpowiedniej konfiguracji LMS, tak by LMS generował pliki konfiguracyjne dla fw.sh w odpowiednim dla niego formacie raz aby możliwe było sterowanie praca fw.sh z poziomu LMS.

# fw.sh shaper_stop|shaper_start|shaper_restart
ta opcja przydaje się jeśli mamy skonfigurowany LMS w ten sposób, że komputerom przypisane zostały taryfy. 
Skrypt obsługuje także taryfe nocną (opcja shaper_restart). Dzialanie Shapera jest zoptymalizowane dla duzych ilości komputerów i taryf.

# fw.sh shaper_stop
Zatrzymuje Shaper

# fw.sh shaper_stop
Uruchamia Shaper

# fw.sh shaper_restart
Pobiera pliki konfiguracyjny Shapera ze zdalnego serwera (LMS) a nastepnie zatrzymuje i ponownie uruchamia Shaper

Aby dostosować ustawienia zadań wykonywanych przez fw.sh shaper w cron do własnych potrzeb, należy wyedytowac funcję fw_cron w pliku fwfunction, a jeśli już skrypt pracuje (został uruchomiony produkcyjnie) to także plik /etc/cron.d/fw_sh
Domyślne wartości ustawione dla dunckji fw_cron:

Terminy przeładowania skryptu ./fw.sh z opcją shaper_restart dla taryfy nocnej od 22:00 do 10:00:

"00 22 * * * /opt/gateway/scripts/fw.sh shaper_restart"</br>
"00 10 * * * /opt/gateway/scripts/fw.sh shaper_restart"</br>

# fw.sh maintenance-on
 W tym trybie wyłącza zaporę, wyłącza interfejsy LAN i WAN, podnosi zaś  interfejs zdefiniowany jako MGMT (management).

# fw.sh maintenance-off
Wykonanie tej komendy powoduje przejście do normalnego trybu pracy.
 
# fw.sh stats

Ten moduł dostarcza szczegółowe statystyki dla kazdego hosta, poprzez odczyt liczników danych z iptables.

Jeśli chcemy zaimportować te statystki ruchu naszych klientów do LMS, należy na maszynie z LMS uruchamiać cyklicznie np. co 5 minut skrypt zapisujący statystyki do bazy danych LMS

Skrypt powinien zawierac dwa polecenia:

ssh -p 222 root@192.168.100.1 '/opt/gateway/scripts/fw.sh stats' > /var/log/traffic.log</br></br>
bash /var/www/html/lms/bin/lms-traffic</br>

gdzie 192.168.100.1 to adres IP naszego rutera na którym pracuje skryp fw.sh.

Polecenie pierwsze uruchomi zdalnie skrypt fw.sh z opcją stats, który odczyta liczniki przesłanych danych dla wszystkich hostów i zapisze je do pliku. Zaś uruchomienie dugiego polecenia uruchomi skrypt, który odczyta plik /var/log/traffic.log i zaimportuje wartości do tabeli stats w bazie danych LMS.
