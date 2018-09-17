
# Opis

fw.sh konfiguruje system linux do pracy jako zapora (firewall), shaper (ograniczanie pasma per komputer lub per grupa komputerów), serwer dhcp. Jest zoptymalizowany dla dużych sieci (od kilkuset do kilku tysięcy komputerów). 
Pobiera swoją konfigurację z plików generowanych przez odpowiednio skonfigurowane instancje LMS (http://lms.org.pl) lub dowolny inny program. Można też pliki konfiguracyjne stworzyć ręcznie ich składnia jest prosta.

W celu optymalnej wydajności przetwarzania pakietów fw.sh korzysta z iptables oraz ipset. To pozwala na wykorzystanie go w sieciach z tysiącami komputerów. Skrypt posiada mechanizm pozwalający na unikanie, kiedy tylko to możliwe, niepotrzebnego przeładowania reguł iptables, korzystając z mechanizmu podmiany gotowych list ipset, oraz podmiany tylko zmienionych reguł iptables resztę pozostawiając bez zmian. 

Do limitowania pakietów wykorzystany jest moduł tc wraz z algorytmem kolejkowania HTB z pakietu iproute2 oraz odpowiednio przemyślana konfiguracja, która pozwala na bardzo dużą wydajność przy zminimalizowanym obciążeniu dla CPU.

fw.sh z modułem stats odczytuje cyklicznie stany liczników pakietów z iptables i ładuje je do pliku. Lms posiada skrypty (np lms-traffic), które pozwalają parsować taki plik i wrzucać z niego dane do tabeli stats bazy danych LMS, co pozwala na generowanie statystyk ruchu dla klientów. 

Domyślnie skrypt pobiera swoje pliki konfiguracyjne łącząc się przez ssh ze zdalną maszyną, na której są tworzone. 
Dla połączenia przez ssh pomiędzy ruterem z fw.sh i serwerem z LMS najlepiej użyć mechaznimu z wykorzystaniem pary kluczy RSA. 
Jeśli pliki są tworzone lokalnie na tej samej maszynie, na której pracuje skrypt fw.sh najprościej jest podać w konfiguracji adres IP 127.0.0.1. 

