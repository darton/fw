
# Opis

Skrypt fw.sh konfiguruje system linux do pracy jako: 

- ruter
- NAT (NAT1:1, wiele grup NAT1:n)
- zapora 
- shaper (ograniczanie pasma per komputer lub per grupa komputerów), 
- serwer DHCP
- dostarcza statystyk ruchu komputerów klientów do bazy danych LMS

Jest zoptymalizowany dla dużych sieci (od kilkuset do kilku tysięcy komputerów). 

Pobiera swoją konfigurację z plików generowanych przez odpowiednio skonfigurowaną instancję LMS (http://lms.org.pl) lub wprost z bazy danych LMS-a.

Można też pliki konfiguracyjne stworzyć ręcznie, np w Excelu, ich składnia jest prosta.

W celu optymalnej wydajności przetwarzania pakietów fw.sh korzysta z iptables oraz ipset. Predystynuje go do wykorzystanie w dużych sieciach. Skrypt fw.sh korzysta z algorytmów pozwalających na unikanie, kiedy tylko to możliwe, niepotrzebnego przeładowania reguł iptables, wykorzystując w zamian podmiany gotowych list ipset, oraz podmiany tylko zmienionych reguł iptables. 

Do limitowania pakietów wykorzystany jest moduł tc wraz z algorytmem kolejkowania HTB z pakietu iproute2 oraz odpowiednio przemyślana konfiguracja, która pozwala na bardzo dużą wydajność przy zminimalizowanym obciążeniu dla CPU.

fw.sh z modułem stats odczytuje cyklicznie stany liczników pakietów z iptables i ładuje je do pliku. LMS posiada skrypty (np lms-traffic), które pozwalają parsować taki plik i wrzucać z niego dane do tabeli stats bazy danych LMS, co pozwala na generowanie statystyk ruchu dla klientów. 

Domyślnie skrypt pobiera swoje pliki konfiguracyjne łącząc się przez ssh ze zdalną maszyną, na której są tworzone. 
Dla połączenia przez ssh pomiędzy ruterem z fw.sh i serwerem z LMS najlepiej użyć mechaznimu z wykorzystaniem pary kluczy RSA. 
Jeśli pliki są tworzone lokalnie na tej samej maszynie, na której pracuje skrypt fw.sh najprościej jest ustawić lms_ip="127.0.0.1" lub ustawić exec_cmd="eval" oraz copy_cmd_url="cp /opt/gateway"

Zalecane jest używanie minimum 4 rdzeniowego procesora.

Dokumentacja do projektu znajduje się na wiki pod adresem https://github.com/darton/fw/wiki
