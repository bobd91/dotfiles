INCLUDE := /usr/include/bash/builtins \
           /usr/include/bash/include \
           /usr/include/bash \
           /usr/lib/bash

unixconnect.so: unixconnect.c
	gcc $(foreach dir,$(INCLUDE),-I $(dir)) -shared -fPIC -o $@ $<
