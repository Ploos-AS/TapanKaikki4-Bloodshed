#include <stdarg.h>
#include <stdlib.h>
#include <string.h>

#include "network.h"

CNetworkAddress& CNetworkAddress::operator =(const CNetworkAddress* aAddr)
{
	(void)aAddr;
	return *this;
}

const char* CNetworkAddress::GetHostname() const
{
	return "";
}

const char* CNetworkAddress::GetAddress() const
{
	return "";
}

CNetworkDevice::CNetworkDevice()
	: iServerAddress(NULL), iLocalAddress(NULL), iBroadCastAddress(NULL)
{
}

CNetworkDevice::~CNetworkDevice()
{
}

void CNetworkDevice::Send(int dest, int type, ...)
{
	(void)dest;
	(void)type;
}

void CNetworkDevice::SendNow(const CNetworkAddress* dest, int type, ...)
{
	(void)dest;
	(void)type;
}

int CNetworkDevice::Available()
{
	return 0;
}

const CNetworkAddress* CNetworkDevice::BroadCastAddress()
{
	return iBroadCastAddress;
}

const CNetworkAddress* CNetworkDevice::LocalAddress()
{
	return iLocalAddress;
}

static char* network_unavailable(int* errval)
{
	if (errval)
		*errval = 1;
	return strdup("Networking is not available in the M1 Amiga build");
}

char* CNetworkDevice::ReadHTTP(const char *host, const char *page, int port, int* errval)
{
	(void)host;
	(void)page;
	(void)port;
	return network_unavailable(errval);
}

char* CNetworkDevice::ReadProxyHTTP(char *proxyaddress, const char *host, const char *page, int proxyport, int* errval)
{
	(void)proxyaddress;
	(void)host;
	(void)page;
	(void)proxyport;
	return network_unavailable(errval);
}
