
Skrypt fw.sh konfiguruje system linux do pracy jako zapora (firewall) i/lub shaper, pobierając swoją konfigurację z plików generowanych przez odpowiednio skonfigurowane instancje LMS (http://lms.org.pl) lub dowolny inny program, można też pliki konfiguracyjne stworzyć ręcznie.

W celu optymalnej wydajności przetwarzania pakietów fw.sh korzysta z iptables oraz ipset. To pozwala na wykorzystanie go w sieciach z tysiącami komputerów. Skrypt posiada mechanizm pozwalający na unikanie, kiedy tylko to możliwe, niepotrzebnego przeładowania reguł iptables, korzystając z mechanizmu podmiany gotowych list ipset, oraz podmiany tylko zmienionych reguł iptables resztę pozostawiając bez zmian. 

Do limitowania pakietów wykorzystany jest moduł tc z pakietu iproute2 oraz odpowiednio przemyślana jego konfiguracja, która pozwala na duża wydajność przy niewielkim obciążeniu dla CPU.

Skrypt odczytuje także cyklicznie stany liczników pakietów z iptables i ładuje je do pliku. Lms posiada skrypty (np lms-traffic) które pozwalają parsować taki plik i wrzucać z niego dane do tabeli stats swojej bazy danych, co pozwala na generowanie statystyk ruchu dla klientów. 

Domyślnie skrypt pobiera swoje pliki konfiguracyjne łącząc się przez ssh ze zdalną maszyną, na której są tworzone. 
Dla połączenia przez ssh pomiędzy ruterem z fw.sh i serwerem z LMS najlepiej użyć mechaznimu z wykorzystaniem pary kluczy RSA. 
Jeśli pliki są tworzone lokalnie na tej samej maszynie, na której pracuje skrypt fw.sh najprościej jest podać w konfiguracji adres IP 127.0.0.1. 

### Instalacja

Jeśli odpowiadają Ci domyślnie ustawione wartości katalogów i nazwy plików konfiguracyjnych:

#curl -sS https://raw.githubusercontent.com/darton/fw/master/install.sh |bash

Jeśli przed instalacją chcesz wcześniej zmienić konfigurację:

#wget https://raw.githubusercontent.com/darton/fw/master/install.sh

po wykonaniu zmian:

bash ./install.sh


### Sposób użycia

 /opt/gateway/scripts/fw.sh </br>
Usage: fw.sh start|stop|restart|reload|stats|lmsd|qos|status|maintenance-on|maintenance-off

### Przygotowanie plików konfiguracyjnych dla skryptu

Konieczne do uruchomienia skryptu pliki konfiguracyjne (domyślnie puste):

fw_public_ip </br>
Zawiera listę hostów z publicznymi adresami IP w formacie: "grantedhost|deniedhost|warnedhost adres_ip"
Plik fw_public_ip służy do prowadzenia rejestru adresów IP, które mają być rutowane (bez NAT)
np

grantedhost 192.168.102.101 </br>
grantedhost 192.168.102.105 </br>
deniedhost 192.168.102.105 </br>

Taki plik może wygenerować odpowiednio skonfigurowany LMS z wykorzystaniem instancji LMSD o nazwie hostfile.

![fw_public_ip](https://user-images.githubusercontent.com/1482900/45300606-271aba00-b50f-11e8-9351-2038fb7432f9.png)

fw_nat_1-1	</br>
Zawiera listę hostów z prywatnymi adresami IP natowanymi 1-1 na adresy publiczne w formacie: "grantedhost|deniedhost|warnedhost prywatny_adres_ip publiczny_adres_ip"

Taki plik może wygenerować odpowiednio skonfigurowany LMS z wykorzystaniem instancji LMSD o nazwie hostfile.

![fw_nat_11](https://user-images.githubusercontent.com/1482900/45298525-0fd8ce00-b509-11e8-9cd4-772522a12cc6.png)

fw_nat_1-n	</br>
Zawiera listę w formacie: "nazwa_pliku_z_lista_adresów_IP publiczny_adres_ip", opisującego powiązania plików z prywatnymi adresami IP i odpowiadającymi im publicznymi adresami IP na które będą NAT-owane

Jeśli mamy wiele adresów ip na, które chemy natować w systemie jeden do wielu, tworzymy osobne pliki dla nich np.: 
fw_nat_ip1, fw_nat_ip2, fw_nat_ip3, fw_nat_ip4, itd. Do każdego pliku wrzucamy listę adresów IP hostów wraz z ich statusami (denied| granted) Zaś w pliku fw_nat_1-n zapisujemy powiązania pomiędzy tymi plikami a adresami IP, na które ma odbywać się natowanie.
 
Przykładowa  zawrtość pliku fw_nat_1-n:
 
fw_nat_ip1 172.16.0.1 </br>
fw_nat_ip2 172.16.0.111 </br>
fw_nat_ip3 172.16.0.222 </br>
fw_nat_ip4 172.16.0.253 </br>

Wtedy wszystkie adresy IP jakie zawiera plik fw_nat_ip1 bedą natowane na adres 172.16.0.1, zaś wszystkie adresy IP zawarte w pliku fw_nat_ip2 będą natowane na adres IP 172.16.0.111 ... itd.

Taki plik może wygenerować odpowiednio skonfigurowany LMS z wykorzystaniem instancji LMSD o nazwie hostfile.

![fw_nat_1n](https://user-images.githubusercontent.com/1482900/45298573-372f9b00-b509-11e8-925d-d544683ffb86.png)

fw_nat_ip1, fw_nat_ip1 ...</br>
Pliki z adresami IP, które mają być natowane na jeden konkretny adres IP.
a jego zawartość powinna wygladać np tak:

grantedhost 192.168.102.96 </br>
deniedhost 192.168.102.99 </br>

Nazwy plików mogą być dowolne, muszą być tylko spójne z tym co zawiera plik fw_nat_1-n.
W przykładzie opisane są nazwy jakie są skonfigurowane na zrzutrach ekranu

Takie plik może wygenerować odpowiednio skonfigurowany LMS z wykorzystaniem instancji LMSD o nazwie hostfile.
Ponizej przykład dla pliku o nazwie fw_nat_ip1

![fw_nat_1n_ip1](https://user-images.githubusercontent.com/1482900/45301748-d9ec1780-b511-11e8-9979-d3822a2dd3d7.png)


fw_routed_ip  </br>
Służy to prowadzenia rejestru sieci oraz adresów IP bramek (gateway) na które te sieci mają być rutowane w formacie:
Sieć/prefiks adres_IP_bramki, przykład: 

172.16.0.128/30 172.16.1.7 </br>
172.16.1.128/30 172.16.1.8 </br>
172.16.3.128/30 172.16.1.9 </br>

Taki plik może wygenerować odpowiednio skonfigurowany LMS z wykorzystaniem instancji LMSD o nazwie hostfile.

![fw_routed_ip](https://user-images.githubusercontent.com/1482900/45300413-8e843a00-b50e-11e8-958c-c71c275f5abd.png)

fw_lan_banned_dst_ports </br>
Zawiera listę portów TCP/IP w formacie: "numer_portu"

Taki plik może wygenerować odpowiednio skonfigurowany LMS z wykorzystaniem instancji LMSD o nazwie hostfile.
![fw_filtered_lan_dstp](https://user-images.githubusercontent.com/1482900/45299914-49133d00-b50d-11e8-8180-29506e57497a.png)


fw_blacklist </br>
Zawiera listę adresów IP i sieci

Taki plik może wygenerować odpowiednio skonfigurowany LMS z wykorzystaniem instancji LMSD o nazwie hostfile.

![fw_blacklist](https://user-images.githubusercontent.com/1482900/45298758-cccb2a80-b509-11e8-8a0d-0dac9852fc53.png)

dhcpd.conf </br>
Zawiera gotowy plik konfiguracyjny dla serwera dhcp

Taki plik może wygenerować odpowiednio skonfigurowany LMS z wykorzystaniem instancji LMSD o nazwie dhcp.
![dhcp](https://user-images.githubusercontent.com/1482900/45298911-377c6600-b50a-11e8-86c9-f626b69772cf.png)

Gdy już mamy gotowe pliki konfiguracyjne uruchamiamy zaporę poleceniem:</br>

## fw.sh start </br>
Polecenie fw.sh start uruchomi zaporę odczytując parametry konfiguracyjne zawarte w plikach konfiguracyjncyh, dokana restartu serwera DHCP oraz reguł shapera.

## fw.sh stop </br>
Wykonanie fw.sh stop zatrzyma zaporę, wyłączy forwardowanie pakietów, włączy domyśłne polityki dla iptables (np FORWARD DENY).

## fw.sh restart </br>
wykona fw.sh start a potem ./fw stop czyli usunie wszystkie reguły iptables oraz ipset i utworzy je na nowo, powoduje to zerwanie wszystkich połączeń i przerę w transmisji na kilka sekund.

## fw.sh reload </br> 
wykona zmiany tylko tych reguł iptables, które się zmieniły: czyli np. usunie lub doda konkretną regułę iptables, lub podmieni tablice ipset. Aby uniknąć przerw w transmisji pakietów odczuwalnych dla wszystkich użytkowników należy korzystać właśnie z opcji reload przy wprowadzaniu zmian.

## fw.sh lmsd
Ten moduł służy do wspólpracy z LMS (http://lms.org.pl). Nasz router/firewall może wtedy pracować w sposób automatyczny.
Sterowanie fw.sh odbywa się wtedy z poziomu LMS. fw.sh  sprawdzi czy w LMS został ustawiony przez operatora status przeładowania danego hosta i wykona przeładowanie lub restart w zależności, które pliki konfiguracyjne i co w nich zostało zmienione. Jeśli pliki nie zostały zmienione, a w LMS został ustawiony status przeładowania, skrypt to wykryje, zmieni status przeładowania w LMS na wykonane,  ale nie wykona restartu/przeładowania, zapisze tylko informacje w logach.

Po instalacji ./fw.sh lmsd jest uruchamiany co minutę przez cron.
uruchamianie fw.sh z modułem lmsd wymaga odpowiedniej konfiguracji LMS, tak by LMS generował pliki konfiguracyjne dla fw.sh w odpowiednim dla niego formacie raz aby możliwe było sterowanie praca fw.sh z poziomu LMS.

## fw.sh shaper_stop|shaper_start|shaper_restart|shaper_stats

ta opcja przydaje się jeśli mamy skonfigurowany LMS w ten sposób, że komputerom przypisane zostały taryfy. 
Skrypt obsługuje także taryfe nocną (opcja shaper_restart). Dzialanie Shapera jest zoptymalizowane dla duzych ilości komputerów i taryf.

### fw.sh shaper_stop
Zatrzymuje Shaper

### fw.sh shaper_stop
Uruchamia Shaper

### fw.sh shaper_restart
Pobiera plik konfiguracyjny Shapera ze zdalnego serwera (LMS) a nastepnie zatrzymuje i ponownie uruchamia Shaper z nową konfiguracją.

Aby dostosować ustawienia zadań wykonywanych przez moduł shaper w cron do własnych potrzeb, należy wyedytowac funcję fw_cron w pliku fwfunction, a jeśli już skrypt pracuje (został uruchomiony produkcyjnie) to także plik /etc/cron.d/fw_sh

Domyślne wartości ustawione dla funkcji fw_cron:

Terminy przeładowania skryptu ./fw.sh z opcją shaper_restart dla taryfy nocnej od 22:00 do 10:00:

"00 22 * * * /opt/gateway/scripts/fw.sh shaper_restart"</br>
"00 10 * * * /opt/gateway/scripts/fw.sh shaper_restart"</br>

Format pliku konfiguracyjnego dla modułu Shapera, którego nazwę określa się w zmiennej shaper_file= skyrptu fw.sh:

Plik musi zaczynać się od deklaracji parametrów:

ISP_RX_LIMIT=470000kbit</br>
ISP_TX_LIMIT=470000kbit</br>
GW_TO_LAN_LIMIT=1000000kbit</br>
GW_TO_WAN_LIMIT=100000kbit</br>
LAN_DEFAULT_LIMIT=128kbit</br>
WAN_DEFAULT_LIMIT=128kbit</br>

gdzie:

ISP_RX_LIMIT oraz ISP_TX_LIMIT to wynikające z kontraktu z operatorem nadrzędnym parametry łącza dostępowego do sieci INternet pomniejszone o ok 5-10% aby uniknąc zapełniania kolejki modemu operatora.</br>

GW_TO_LAN_LIMIT to limit ruchu wychodzącego do sieci LAN, którego źródłem jest Gateway na którym pracuje skrypt fw.sh</br>

GW_TO_WAN_LIMIT to limit ruchu wychodzącego do sieci WAN, którego źródłem jest Gateway na którym pracuje skrypt fw.sh</br>

LAN_DEFAULT_LIMIT to limit dla ruchu wychodzącego do sieci LAN nie sklasyfikowanego, czyli komputerów urządzeń nie ujętych w pliku konfiguracyjnym dla modułu Shaper</br>

WAN_DEFAULT_LIMIT to limit dla ruchu wychodzącego do sieci WAN nie sklasyfikowanego, czyli komputerów urządzeń nie ujętych w pliku konfiguracyjnym dla modułu Shaper</br>


Następnie dla każdego hosta powinny być określone parametry klas UP/DOWN HTB, przy czym kilka hostów może być przypisanych do jednej pary klasy HTB.

Przykładowa konfiguracja dla jednego hosta przypisanego do jednej pary klas UP/DOWN:

100 customer 1</br>
100 class_up 8kbit 1024kbit</br>
100 class_down 8kbit 5120kbit</br>
100 filter 192.168.101.24</br>

dla kilku hostów przypisanych do pary klas:

101 customer 2</br>
101 class_up 8kbit 1024kbit</br>
101 class_down 8kbit 5120kbit</br>
101 filter 192.168.10.24</br>
101 filter 192.168.10.25</br>
101 filter 192.168.10.26</br>

Klient może mieć kilka taryf (kilka umów na usługi) i przypisane do nich różne komputery. Wtedy dla każdej taryfy trzeba wygenerować odpowiedni zestaw rekordów. Np jeśli klient o id 1 miałby jeszcze dwie dodatkowe umowy/taryfy z przypisanymi do nich po po jednym modemie/komputerze, należy dodać następujące rekordy

102 customer 1</br>
102 class_up 8kbit 1024kbit</br>
102 class_down 8kbit 5120kbit</br>
102 filter 192.168.101.30</br>
103 customer 1</br>
103 class_up 8kbit 1024kbit</br>
103 class_down 8kbit 5120kbit</br>
103 filter 192.168.101.34</br>

Gdzie pierwsza kolumna zawiera unikalnę liczbę identyfikującą klienta w połączeniu z daną taryfą, jeśli klient ma kilka taryf dla każdej ta liczba musi byc unikalna.</br>
Cyfry po słowie customer to unikalne id klientów w LMS</br>
Wyrazenia class_up oraz class_down mają jako parametry rate oraz ceil, gdzie RATE to jest minimalna gwarantowana przepustowość, a CEIL to maksymalna niegwarantowana przepustowość</br>
Wyrażenie filter jako parametr ma zaś adres ip hosta, którego dotyczy konfiguracja</br>

Taki plik może wygenerować odpowiednio skonfigurowany LMS z wykorzystaniem instancji lmsd o nazwie tc-new.

![lms-shaper-config](https://user-images.githubusercontent.com/1482900/45297761-aeaffb00-b506-11e8-82b6-d8ddfb6782aa.png)

## fw.sh shaper_stats

Ta opcja modułu shaper dostarcza szczegółowe statystyki dla każdego hosta, poprzez odczyt z liczników iptables.

Jeśli chcemy zaimportować statystki ruchu naszych klientów do LMS, należy na maszynie z LMS uruchamiać cyklicznie np. co 5 minut  skrypt zapisujący statystyki do bazy danych LMS. Mmusi to być taki sam czas jaki jest ustawiony w phpui LMS w parametrze stat_freq
Czyli jeśłi wybierzemy  uruchaminie co 5 minut to stat_freq=300 (sekund)

Skrypt powinien zawierac dwa polecenia:

ssh -p 222 root@192.168.100.1 '/opt/gateway/scripts/fw.sh stats' > /var/log/traffic.log</br>
bash /var/www/html/lms/bin/lms-traffic</br>

gdzie 192.168.100.1 to adres IP naszego rutera na którym pracuje skryp fw.sh.

Polecenie pierwsze uruchomi zdalnie skrypt fw.sh z modułem stats, który odczyta liczniki przesłanych danych dla wszystkich hostów i zapisze je do pliku. Zaś drugie polecenie uruchomi skrypt, który odczyta plik /var/log/traffic.log i zaimportuje wartości do tabeli stats w bazie danych LMS.

## fw.sh maintenance-on
 W tym trybie wyłącza zaporę, wyłącza zadania uruchamiane w cron, wyłącza serwer DHCP, wyłącza interfejsy LAN i WAN, podnosi zaś  interfejs zdefiniowany jako MGMT (management) i uruchamia na nim klienta DHCP .

## fw.sh maintenance-off
Wykonanie tej komendy powoduje przejście do normalnego trybu pracy.

## Kompletna lista instancji lmsd użysta w programie LMS do współpracy z fw.sh

![lmsd_lista_instancji](https://user-images.githubusercontent.com/1482900/45300890-d5befa80-b50f-11e8-966c-79eda656aafa.png)
