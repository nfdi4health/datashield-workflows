\name{ds.merge}
\alias{ds.merge}
\title{Merge}
\usage{
ds.merge(
  x.name,
  y.name,
  by.x.names,
  newobj.name = "merge.newobj",
  datasources = NULL
)
}
\arguments{
\item{x.name}{a character string naming the first data frame.}

\item{y.name}{a character string naming the second data frame.}

\item{by.x.names}{column names in x to merge by.}

\item{newobj.name}{the name of the new object created on the server.}

\item{datasources}{a list of DSConnection-class objects.}
}
\examples{
\dontrun{ds.merge(x.name = "D", y.name = "E", by.x.names = "id")}
}
