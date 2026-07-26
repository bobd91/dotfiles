
#include <config.h>

#if defined (HAVE_UNISTD_H)
#  include <unistd.h>
#endif
#include "bashansi.h"
#include <stdio.h>
#include <errno.h>

#include <sys/socket.h>
#include <sys/un.h>

#include "bashtypes.h"
#include "typemax.h"
#include "loadables.h"

#if !defined (errno)
extern int errno;
#endif

extern char *strerror (int);

static int bind_fd_variable (char *varname, int fd);

int
unixconnect_builtin (WORD_LIST *list)
{
	struct sockaddr_un addr = { .sun_family=AF_UNIX };

	int opt, pathlen, sd;
	char *fdvar="UNIXCONNECT_FD";

	reset_internal_getopt ();
	while ((opt = internal_getopt (list, "v:")) != -1)
	{
		switch (opt)
		{
			case 'v':
				fdvar = list_optarg;
				break;
			default:
				builtin_usage ();
				return EX_USAGE;
		}
	}
	list = loptend;

	unbind_variable(fdvar);

	if(list == 0)
	{
		builtin_usage();
		return EX_USAGE;
	}

	pathlen=strnlen(list->word->word, sizeof(addr.sun_path));

	if( pathlen == sizeof(addr.sun_path))
	{
		builtin_error("socket path too long (max %d)", pathlen - 1);
		return EXECUTION_FAILURE;
	}

	strcpy(addr.sun_path, list->word->word);

	sd = socket(AF_UNIX, SOCK_STREAM, 0);
	if (sd == -1)
	{
		builtin_error ("cannot create socket: %s", strerror (errno));
		return EXECUTION_FAILURE;
	}

	if (connect(sd, (struct sockaddr *) &addr,
				sizeof(struct sockaddr_un)) == -1) {
		builtin_error("cannot connect to socket: %s", strerror(errno));
		close(sd);
		return EXECUTION_FAILURE;
	}

	bind_fd_variable(fdvar, sd);

	return EXECUTION_SUCCESS;
}

static int
bind_fd_variable (char *varname, int fd)
{
	SHELL_VAR *v;
	char ibuf[INT_STRLEN_BOUND (int) + 1], *p;

	p = fmtulong (fd, 10, ibuf, sizeof (ibuf), 0);
	v = builtin_bind_variable (varname, p, 0);
	if (v == 0 || readonly_p (v) || noassign_p (v))
		builtin_error ("%s: cannot set variable", varname);
	return (v != 0);
}

char *unixconnect_doc[] = {
	"Connect to a Unix Domain Socket.",
	"",
	"The socket path should be supplied as the argument",
	"",
	"Options, if supplied, have the following meanings:",
	"    -v varname    store the file descriptor of the connected",
	"                  socket into varname (default UNIXCONNECT_FD)",
	"",
	"If successful, the shell variable named by varname will be set to the",
	"file descriptor of the connected socket.  The return status is 0.",
	"",
	"On failure, the return status is 1 and varname will be unset.",
	(char *) NULL
};

struct builtin unixconnect_struct = {
	"unixconnect",		/* builtin name */
	unixconnect_builtin,	/* function implementing the builtin */
	BUILTIN_ENABLED,	/* initial flags for builtin */
	unixconnect_doc,	/* array of long documentation strings. */
	"unixconnect [-v varname] path", /* usage synopsis; becomes short_doc */
	0			/* reserved for internal use */
};

