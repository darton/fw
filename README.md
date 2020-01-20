
# Opis

Skrypt fw.sh konfiguruje system linux do pracy jako: 

- ruter
- zapora (firewall), 
- shaper (ograniczanie pasma per komputer lub per grupa komputerów), 
- serwer dhcp
- dostarcza statystyk ruchu komputerów klientów do bazy danych LMS

Jest zoptymalizowany dla dużych sieci (od kilkuset do kilku tysięcy komputerów). 
Pobiera swoją konfigurację z plików generowanych przez odpowiednio skonfigurowaną instancję LMS (http://lms.org.pl) lub wprost z bazy danych LMS-a.

Można też pliki konfiguracyjne stworzyć ręcznie, ich składnia jest prosta.

W celu optymalnej wydajności przetwarzania pakietów fw.sh korzysta z iptables oraz ipset. Pozwala to na wykorzystanie go w sieciach z tysiącami komputerów. Skrypt korzysta z algorytmów pozwalających na unikanie, kiedy tylko to możliwe, niepotrzebnego przeładowania reguł iptables, wykorzystując w zamian podmiany gotowych list ipset, oraz podmiany tylko zmienionych reguł iptables. 

Do limitowania pakietów wykorzystany jest moduł tc wraz z algorytmem kolejkowania HTB z pakietu iproute2 oraz odpowiednio przemyślana konfiguracja, która pozwala na bardzo dużą wydajność przy zminimalizowanym obciążeniu dla CPU.

fw.sh z modułem stats odczytuje cyklicznie stany liczników pakietów z iptables i ładuje je do pliku. LMS posiada skrypty (np lms-traffic), które pozwalają parsować taki plik i wrzucać z niego dane do tabeli stats bazy danych LMS, co pozwala na generowanie statystyk ruchu dla klientów. 

Domyślnie skrypt pobiera swoje pliki konfiguracyjne łącząc się przez ssh ze zdalną maszyną, na której są tworzone. 
Dla połączenia przez ssh pomiędzy ruterem z fw.sh i serwerem z LMS najlepiej użyć mechaznimu z wykorzystaniem pary kluczy RSA. 
Jeśli pliki są tworzone lokalnie na tej samej maszynie, na której pracuje skrypt fw.sh najprościej jest ustawić lms_ip="127.0.0.1" lub ustawić exec_cmd="eval" oraz copy_cmd_url="cp /opt/gateway"

Dokumentacja do projektu znajduje się na wiki pod adresem https://github.com/darton/fw/wiki
