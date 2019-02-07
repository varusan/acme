
.PHONY: test pebble pebble_setup pebble_start pebble_wait pebble_stop boulder boulder_setup boulder_start boulder_stop


GOPATH ?= $(HOME)/go
BOULDER_PATH ?= $(GOPATH)/src/github.com/letsencrypt/boulder
PEBBLE_PATH ?= $(GOPATH)/src/github.com/letsencrypt/pebble


# tests the code against a running ca instance
test:
	$(eval COVERAGE = coverage_$(strip $(shell ls coverage* 2>/dev/null | wc -l)).txt)
	GOCACHE=off go test -race -coverprofile=$(COVERAGE) -covermode=atomic github.com/varusan/acme/...

clean:
	rm -f coverage_*.txt


pebble: pebble_setup pebble_start pebble_wait test pebble_stop

pebble_setup:
	mkdir -p $(PEBBLE_PATH)
	git clone --depth 1 https://github.com/letsencrypt/pebble.git $(PEBBLE_PATH) 2> /dev/null \
		|| (cd $(PEBBLE_PATH); git reset --hard HEAD && git pull -q)

# runs an instance of pebble using docker
pebble_start:
	docker-compose -f $(PEBBLE_PATH)/docker-compose.yml up -d

# waits until pebble responds
pebble_wait:
	while ! wget --delete-after -q --no-check-certificate "https://localhost:14000/dir" ; do sleep 1 ; done

# stops the running pebble instance
pebble_stop:
	docker-compose -f $(PEBBLE_PATH)/docker-compose.yml down


boulder: boulder_setup boulder_start boulder_wait test boulder_stop

# NB: this edits docker-compose.yml
boulder_setup:
	mkdir -p $(BOULDER_PATH)
	git clone --depth 1 https://github.com/letsencrypt/boulder.git $(BOULDER_PATH) 2> /dev/null \
		|| (cd $(BOULDER_PATH); git reset --hard HEAD && git pull -q)
	sed -i -e 's/test\/config$$/test\/config-next/' $(BOULDER_PATH)/docker-compose.yml

# runs an instance of boulder
boulder_start:
	docker-compose -f $(BOULDER_PATH)/docker-compose.yml up -d

# waits until boulder responds
boulder_wait:
	while ! wget --delete-after -q --no-check-certificate "http://localhost:4001/directory" ; do sleep 1 ; done

# stops the running docker instance
boulder_stop:
	docker-compose -f $(BOULDER_PATH)/docker-compose.yml down
