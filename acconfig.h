/*
 * HAVE_SIGACTION is defined iff sigaction() is available.
 */
#undef	HAVE_SIGACTION

/*
 * HAVE_STRERROR is defined iff the standard libraries provide strerror().
 */
#undef	HAVE_STRERROR

/*
 * NLIST_HAS_N_NAME is defined iff a struct nlist has an n_name member.
 * If it doesn't then we assume it has an n_un member which, in turn,
 * has an n_name member.
 */
#undef	NLIST_HAS_N_NAME

/*
 * HAVE_SYS_SELECT_H is defined iff we have the include file sys/select.h.
 */
#undef	HAVE_SYS_SELECT_H

/*
 * USCORE is defined iff C externals are prepended with an underscore.
 */
#undef	USCORE

@BOTTOM@

#include "fake/sigact.h"
#include "fake/strerror.h"
#include "fake/sys-select.h"
