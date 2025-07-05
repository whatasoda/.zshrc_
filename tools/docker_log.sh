dockerlog() {
  count=$1
  services=${@[@]:2}
  echo $services | xargs docker compose logs --tail $count -f 
}
