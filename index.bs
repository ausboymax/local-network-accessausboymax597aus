<pre class='metadata'>
Title: Local Network Access
Shortname: LNA
Level: None
Status: w3c/UD
Repository: WICG/local-network-access
URL: https://wicg.github.io/local-network-access/
Editor: Chris Thompson, Google https://google.com, cthomp@google.com
Editor: Hubert Chao, Google https://google.com, hchao@google.com
Abstract: Restrict access to the users' local network with a new permission
Markup Shorthands: markdown yes, css no
Complain About: accidental-2119 yes, missing-example-ids yes
Assume Explicit For: yes
Die On: warning
WPT Path Prefix: TODO-API-LABEL
WPT Display: closed
Include MDN Panels: if possible
Include Can I Use Panels: yes
</pre>

Introduction {#intro}
=====================

## 1\. Introduction

*This section is not normative.*

Although \[RFC1918\] has specified a distinction between "private" and "public"
internet addresses for over two decades, user agents haven’t made much progress
at segregating the one from the other. Websites on the public internet can make
requests to local devices and servers, which enable a number of malicious
behaviors, including attacks on users' routers like those documented in
\[[DRIVE-BY-PHARMING\]](https://link.springer.com/chapter/10.1007/978-3-540-77048-0_38),
[\[SOHO-PHARMING\]](https://web.archive.org/web/20231024165504/https://331.cybersec.fun/TeamCymruSOHOPharming.pdf)
and
\[[CSRF-EXPLOIT-KIT](https://web.archive.org/web/20191223022525/https://malware.dontneedcoffee.com/2015/05/an-exploit-kit-dedicated-to-csrf.html)\].

Local Network Access aims to prevent these undesired requests to insecure
devices on the local network. This is achieved by deprecating direct access to
local IP addresses from public websites, and instead requiring that the user
grants permission to the initiating website to make connections to their local
network.

*Note:* This proposal builds on top of Chrome's previously paused [Private
Network Access (PNA)
work](https://github.com/WICG/private-network-access/blob/main/explainer.md),
but differs by gating access on a permission rather than via preflight
requests.

### 1.1. Goals

The overarching goal is to prevent the user agent from inadvertently enabling
attacks on devices running on a user’s local intranet, or services running on
the user’s machine directly. For example, we wish to mitigate attacks on:

* Users' routers, as outlined in \[SOHO-PHARMING\]. Note that status quo CORS protections don’t protect against the kinds of attacks discussed here as they rely only on [CORS-safelisted methods](https://fetch.spec.whatwg.org/#cors-safelisted-method) and [CORS-safelisted request-headers](https://fetch.spec.whatwg.org/#cors-safelisted-request-header). No CORS preflight is triggered, and the attacker doesn’t care about reading the response, as the request itself is the CSRF attack.

* Software running a web interface on a user’s loopback address. For better or worse, this is becoming a common deployment mechanism for all manner of applications, and often assumes protections that simply don’t exist (see \[[AVASTIUM](https://project-zero.issues.chromium.org/issues/42452198)\] and \[[TREND-MICRO](https://project-zero.issues.chromium.org/issues/42452214)\] for recent examples).

There should be a well-lit path to allow these requests when the user is both
expecting and explicitly allowing the local network access requests to occur.
For example, a user logged in to [plex.tv](https://plex.tv) may want to allow
the site to connect to their local media server to directly load media content
over the local network instead of routing through remote servers. See S1.2
below for more examples.

### 1.2. Non-goals

This spec does not attempt to make it easier to use HTTPS connections on local
network devices. While this would be a useful goal, solving this problem is out
of scope for this specification

### 1.2. Examples

#### **1.2.1. User granting permission**

EXAMPLE 1
Alice is at home on her laptop browsing the internet. She has a printer on her
local network built by Acme Printing Company that is running a simple HTTP
server. Alice is having a problem with the printer not properly functioning.

Alice goes to Acme Printing Company's web site to help diagnose the problem.
Acme Printing Company's web site tells Alice that it can connect to the printer
to look at the diagnostic output of the printer. Alice's browser asks Alice to
allow https://support.acmeprintingcompany.com to connect to local devices on
her network. Alice grants permission for
https://support.acmeprintingcompany.com to connect to local devices on her
network, and https://support.acmeprintingcompany.com connects to her local
printer's diagnostic output, and tells Alice that a part is malfunctioning on
the printer and needs to be replaced.

#### **1.2.2. User denying permission**

EXAMPLE 2
Alice continues browsing online to find the best price for the replacement part
on her printer. While looking at a general tech support forum, she suddenly
gets a permission request in her browser for https://printersupport.evil.com to
connect to local devices on her local network. Being suspicious of why
https://printersupport.evil.com would need to connect to local devices, she
denies the permission request.

#### **1.2.3. New device configuration**

EXAMPLE 3
Instead of replacing the part on the printer, Alice decides instead to buy a
new printer from Beta Manufacturing. Upon plugging in the printer and
connecting it to her local network, Alice follows the instructions and goes to
https://setup.betaprinters.com on her laptop. Upon opening the site, she sees a
button that will help her set up the printer defaults. Hitting the button, she
gets a permission prompt asking for permission for
https://setup.betaprinters.com to connect to her local devices, which she
accepts.

## 2\. Framework

### 2.1. IP Address Space

Define IPAddressSpace as follows:

enum IPAddressSpace { "public", "local" };

Every IP address belongs to an ***IP address space***, which can be one of two different values:

1. ***local***: contains addresses that have meaning only within the current
network. In other words, addresses whose target differs based on network
position. This includes loopback addresses, which are only accessible on the
local host (and thus differ for every device).

2. ***public***: contains all other addresses. In other words, addresses whose
target is the same for all devices globally on the IP network.

For convenience, we additionally define the following terms:

1. A **local address** is an IP address whose IP address space is local.
2. A **public address** is an IP address whose IP address space is public.

An IP address space *lhs* is ***less public*** than an IP address space *rhs* if any of the following conditions holds true:

1. lhs is loopback and rhs is either local or public.
2. lhs is local and rhs is public.

To ***determine the IP address space*** of an IP address address, run the following steps:

1. If address belongs to the ::ffff:0:0/96 "IPv4-mapped Address" address block, then replace address with its embedded IPv4 address.
2. For each row in the Non-public IP address blocks" table below:
   1. If address belongs to row’s address block, return row’s address space.
3. Return public.

| Address block | Name | Reference | Address space |
| :---- | :---- | :---- | :---- |
| 127.0.0.0/8 | IPv4 Loopback | \[[RFC1122](https://datatracker.ietf.org/doc/html/rfc1122#page-31)\] | loopback |
| 10.0.0.0/8 | Private Use | \[[RFC1918](https://datatracker.ietf.org/doc/html/rfc1918#section-3)\] | local |
| 100.64.0.0/10 | Carrier-Grade NAT | \[[RFC6598](https://datatracker.ietf.org/doc/html/rfc6598#section-7)\] | local |
| 172.16.0.0/12 | Private Use | \[[RFC1918](https://datatracker.ietf.org/doc/html/rfc1918#section-3)\] | local |
| 192.168.0.0/16 | Private Use | \[[RFC1918](https://datatracker.ietf.org/doc/html/rfc1918#section-3)\] | local |
| 198.18.0.0/15 | Benchmarking | \[[RFC2544](https://www.ietf.org/rfc/rfc2544.txt)\] | loopback |
| 169.254.0.0/16 | Link Local | \[[RFC3927](https://datatracker.ietf.org/doc/html/rfc3927)\] | local |
| ::1/128 | IPv6 Loopback | \[[RFC4291](https://datatracker.ietf.org/doc/html/rfc4291#section-2.4)\] | loopback |
| fc00::/7 | Unique Local | \[[RFC4193](https://datatracker.ietf.org/doc/html/rfc4193#section-3)\] | local |
| fe80::/10 | Link-Local Unicast | \[[RFC4291](https://datatracker.ietf.org/doc/html/rfc4291#section-2.4)\] | local |
| ::ffff:0:0/96 | IPv4-mapped | \[[RFC4291](https://datatracker.ietf.org/doc/html/rfc4291#section-2.5.5.2)\] | see mapped IPv4 address |

User Agents MAY allow certain IP address blocks' address space to be overridden
through administrator or user configuration. This could prove useful to protect
e.g. IPv6 intranets where most IP addresses are considered public per the
algorithm above, by instead configuring user agents to treat the intranet as
private.

Note: Link-local IP addresses lose their meaning if shared across links. This
is not fundamentally different from non-public IP addresses, which all have
some degree of locality beyond which they become ambiguous, but it does present
a particular risk of confused deputy issues.
\[[LINK-LOCAL-URI](https://www.ietf.org/archive/id/draft-ietf-6man-rfc6874bis-07.html)\]
attempts to solve this problem by defining a syntax for link-local IP addresses
in URIs.

Note: The contents of each IP address space were at one point determined in
accordance with the IANA Special-Purpose Address Registries
(\[[IPV4-REGISTRY](%20https://www.iana.org/assignments/iana-ipv4-special-registry/iana-ipv4-special-registry.xhtml)\]
and
\[[IPV6-REGISTRY](https://www.iana.org/assignments/iana-ipv6-special-registry/iana-ipv6-special-registry.xhtml)\])
and the Globally Reachable bit defined therein. This turned out to be an
inaccurate signal for our uses, as described in [PNA's spec issue
\#50](https://github.com/WICG/private-network-access/issues/50).

Note: [Private Network Access
(PNA)](https://github.com/WICG/private-network-access/blob/main/explainer.md)
used the address spaces `public`, `private`, and `local`. This specification
simplifies the address spaces by combining PNA’s `private` and `local` together
into the `local` address space.

ISSUE: Remove the special case for IPv4-mapped IPv6 addresses once access to
these addresses is blocked entirely. [\[PNA Issue
\#36\]](https://github.com/wicg/private-network-access/issues/36)

### 2.2. Local Network Request

A [request](https://fetch.spec.whatwg.org/#fetch-params-request) (*request*) is
a local network request if *request*’s [current
url](https://fetch.spec.whatwg.org/#concept-request-current-url)'s
[host](https://url.spec.whatwg.org/#dom-url-host) maps to an IP address whose
IP address space is less public than *request*’s [policy
container](https://fetch.spec.whatwg.org/#concept-request-policy-container)'s
IP address space.

The classification of IP addresses into two address spaces is an imperfect and
theoretically-unsound approach. It is a proxy used to determine whether two
network endpoints should be allowed to communicate freely or not, in other
words whether endpoint A is reachable from endpoint B without pivoting through
the user agent on endpoint C.

This approach has some flaws:

* false positives: an intranet server with a public address might not be able to directly issue requests to another server on the same intranet with a local address.
* false negatives: a client connected to two different local networks, say a home network and a VPN, might allow a website served from the VPN to access devices on the home network. See also the issue below.

Even so, this specification aims to offer a pragmatic solution to a security
issue that broadly affects most users of the Web whose network configurations
are not so complex.

ISSUE: The definition of local network requests could be expanded to cover all
cross-origin requests for which the [current
url](https://fetch.spec.whatwg.org/#concept-request-current-url)'s
[host](https://url.spec.whatwg.org/#dom-url-host) maps to an IP address whose
IP address space is not public. This would prevent a malicious server on the
local network from attacking other servers, including servers on `localhost`.
Currently, Chromium only implements Local Network Access restrictions for
`public` to `local` requests, and does not enforce the permission for
cross-origin `local` requests. This can be shipped as an incremental
improvement later on. [\[PNA Issue
\#39\]](https://github.com/wicg/private-network-access/issues/39) We note that,
because local names and addresses are not meaningful outside the bounds of the
network, implementers may want to use a different permission prompt for the
cross-origin `local` case than for the `public` to `local` case, and may want
to scope these permission grants to the specific network or to the current
browsing session only.

NOTE: Requests originating from the loopback address should not be considered
local network requests, and should not be subject to local network access
checks, since any software running on the user’s device is already in the most
privileged vantage point on the user’s network.

NOTE: Some local network requests are more challenging to secure than others.
See § 4.4 Rollout difficulties for more details.

### 2.3. Permission Prompt

A local network access permission prompt is introduced to allow for users to
approve of network requests from public websites to local network servers.

When a local network request is detected, a prompt is shown to the user asking
for permission to access the local network. If the user decides to grant the
permission, then the fetch continues. If not, it fails.

The exact scope of the permission is implementation-defined. The permission may
be as coarse-grained as allowing a specific origin to send local network
requests to any endpoint on the local network, or may be more fine-grained to
only allow specific origins to communicate with specific endpoints on the local
network. A user agent may persist this decision to reduce permission fatigue.

### 2.4 Secure Context Restriction

The capability to make local network requests is a [powerful
feature](https://w3c.github.io/permissions/#dfn-powerful-feature) and must only
be allowed from secure contexts.

ISSUE: To be able to apply LNA checks to all cross-origin `local` requests (see
Issue above), Chromium plans to exempt local servers that likely cannot
currently get publicly trusted HTTPS certificates from this requirement (e.g.,
servers on `.local` and private IP literals). See Section 4.4 (Rollout
Difficulties) below for more discussion, and also see
[https://github.com/WICG/private-network-access/issues/96](https://github.com/WICG/private-network-access/issues/96).

### 2.5 Mixed content

Many local network servers do not run HTTPS, as it has proven difficult (and
sometimes even impossible) to migrate private network servers away from HTTP.
This is problematic as the secure context restriction, combined with mixed
content checks, would block many local network requests even if the user would
give permission for the request to occur.

One solution to this problem is to bypass mixed content checks in situations
where the request is known to be a local network request. This is known in a
few situations:

* When the hostname of the request target is an IP literal identified as “local” in the table in the “determine the IP address space” algorithm above (e.g., an RFC1918 IP literal)
* When the hostname of the request is a .local domain ([RFC 6762](https://datatracker.ietf.org/doc/html/rfc6762#section-3))

There may be situations in which neither of the above situations is true, and
yet the site wants to identify a request as being a local network request. This
can be mitigated by adding a new parameter to the fetch() options bag:

fetch("http://router.local/ping", {
  targetAddressSpace: "local",
});

This instructs the browser to allow the fetch to bypass mixed-content checks
even though the scheme is non-secure and potentially obtain a connection to the
target server. The new fetch() API is backward-compatible.

Note that this feature cannot be abused to bypass mixed content in general. If
the resolved remote IP address does not belong to the IP address space
specified as the targetAddressSpace option value, then the request will fail.
If it does belong, then the permission can be checked to allow or fail the
request.

\[TODO: Decide if we want to keep the CSP directive `treat-as-public-address`
around, see
[https://wicg.github.io/private-network-access/\#csp](https://wicg.github.io/private-network-access/#csp).
This directive would be obviated if we implemented
[https://github.com/wicg/private-network-access/issues/39](https://github.com/wicg/private-network-access/issues/39).\]

## 3\. Integrations

*This section is non-normative.*

This document proposes a number of modifications to other specifications in order to implement the mitigations sketched out in the examples above. These integrations are outlined here for clarity, but the external documents are the normative references.

### 3.1. Integration with Permissions

This document defines a [powerful
feature](https://w3c.github.io/permissions/#dfn-powerful-feature) identified by
the [name](https://w3c.github.io/permissions/#dfn-name) "local-network-access".
It overrides the following type:

[**permission descriptor type**](https://w3c.github.io/permissions/#dfn-permission-descriptor-type)
The [permission descriptor type](https://w3c.github.io/permissions/#dfn-permission-descriptor-type) of the "local-network-access" feature is defined by the following WebIDL interface that [inherits](https://webidl.spec.whatwg.org/#dfn-inherit-dictionary) from the default [permission descriptor type](https://w3c.github.io/permissions/#dfn-permission-descriptor-type):

dictionary ***LocalNetworkAccessPermissionDescriptor***
    : [PermissionDescriptor](https://w3c.github.io/permissions/#dom-permissiondescriptor) {

  [DOMString](https://webidl.spec.whatwg.org/#idl-DOMString) ***id***;

};

### 3.2. Integration with Fetch

This document proposes a few changes to Fetch, with the following implication:
local network requests are only allowed if their
[client](https://fetch.spec.whatwg.org/#concept-request-client) is a [secure
context](https://html.spec.whatwg.org/multipage/webappapis.html#secure-context)
**and** permission is granted by the user. If the request would have been
blocked as mixed content, it can be allowed as long as the website states its
intention to access the private network, and users give permission.

Note: This includes navigations. These can indeed be used to trigger CSRF
attacks, albeit with less subtlety than with subresource requests.

####

ISSUE: Chromium only applies LNA restrictions to iframe navigations currently.
It may be worth expanding this to include main-frame navigations (especially
popup windows which can be controlled by their opener).

Note: \[[FETCH](https://fetch.spec.whatwg.org/)\] does not yet integrate the
details of DNS resolution into the
[Fetch](https://fetch.spec.whatwg.org/#concept-fetch) algorithm, though it does
define an [obtain a
connection](https://fetch.spec.whatwg.org/#concept-connection-obtain) algorithm
which is enough for this specification. Local Network Access checks are applied
to the newly-obtained connection. Given complexities such as Happy Eyeballs
(\[RFC6555\], \[RFC8305\]), these checks might pass or fail
non-deterministically for hosts with multiple IP addresses that straddle IP
address space boundaries.

#### **3.2.1. Fetching**

What follows is a sketch of a potential solution:

1. [Connection](https://fetch.spec.whatwg.org/#concept-connection) objects are given a new ***IP address space*** property, initially null. This applies to WebSocket connections too.
2. A new step is added to the [obtain a connection](https://fetch.spec.whatwg.org/#concept-connection-obtain) algorithm immediately before appending *connection* to the user agent’s [connection pool](https://fetch.spec.whatwg.org/#concept-connection-pool):
   1. Set *connection*’s IP address space to the result of running the determine the IP address space algorithm on the IP address of *connection*’s remote endpoint.
      ISSUE: The remote endpoint concept is not specified in \[FETCH\] yet, hence this is still handwaving to some extent. [\[Issue \#33\]](https://github.com/wicg/private-network-access/issues/33)
3. [Request](https://fetch.spec.whatwg.org/#fetch-params-request) objects are given a new ***target IP address space*** property, initially null.
4. [Response](https://fetch.spec.whatwg.org/#concept-response) objects are given a new ***IP address space*** property, whose value is an IP address space, initially null.
5. Define a new ***Local Network Access check*** algorithm. Given a [request](https://fetch.spec.whatwg.org/#fetch-params-request) *request* and a [connection](https://fetch.spec.whatwg.org/#concept-connection) *connection*:
   1. If *request*’s origin is a potentially trustworthy origin and *request*’s current URL’s origin is same origin with *reques*t’s origin, then return null.
   2. If *request*’s policy container is null, then return null.
      NOTE: If *request*’s policy container is null, then LNA checks do not apply to *request*. Users of the fetch algorithm should take care to either set request’s client to an environment settings object with a non-null policy container and let fetch initialize request’s policy container accordingly, or to directly set request’s policy container to a non-null value.
   3. If *request*’s target IP address space is not null, then:
      1. Assert: *request*’s target IP address space is not public.
      2. If *connection*’s IP address space is not equal to *request*’s target IP address space, then return a network error.
      3. Return null.
   4. If connection’s IP address space is less public than request’s policy container's IP address space, then:
      1. Let *error* be a network error.
      2. If *request*’s client is not a secure context (including if it is null), then return *error*.
      3. Set *error*’s IP address space property to *connection*’s IP address space.
      4. \[TODO: Permission check is sketched out below, wording is still vague\]
         1. If the initiating origin has been granted the local network access permission, return null.
         2. If the initiating origin has been denied the local network access permission, return *error*.
         3. Otherwise, prompt the user:
            1. If the user grants permission, return null.
            2. If the user denies the permission, return *error*.
   5. Return null.
6. The fetch algorithm is amended to add 2 new steps right after request’s policy container is set:
   1. If *request*’s target IP address space is null:
      1. If *request*’s URL’s host *host* is an IP address and the result of running the determine the IP address space algorithm on *host* is “local”, then set *request*’s target IP address space property to “local”.
      2. If *request*’s URL’s host’s public suffix is “local”, then set *request*’s target IP address space property to “local”.
      3. NOTE: We could also set the target IP address space to `local` if the request’s URL’s host is “localhost” or “127.0.0.1” (because of \[let-localhost-be-localhost\]), but we do not need special handling for the loopback case as it is already considered to be potentially trustworthy and won’t trigger mixed content checks.
      4. NOTE: We also explicitly do *not* set the target address space property in the public case, because that breaks the next step here... (but maybe we could just skip that??)
      5. NOTE: We don’t set the target IP address space here if it was already non-null in order to prefer the explicit targetAddressSpace if set by the fetch() API.
   2. If *request*’s target IP address space is public, then return a network error.
      1. OPEN QUESTION: Do we need this? Under what conditions can this get set to “public”?
7. The HTTP-network fetch algorithm is amended to add 3 new steps right after checking that the newly-obtained connection is not failure:
   1. Set *response*’s IP address space to *connection*’s IP address space.
   2. Let *localNetworkAccessCheckResult* be the result of running Local Network Access check for *fetchParams*’ request and *connection*.
   3. If *localNetworkAccessCheckResult* is a network error, return *localNetworkAccessCheckResult*.
8. Define a new algorithm called HTTP-no-service-worker fetch based on the existing steps in HTTP fetch that are run if response is still null after handling the fetch via service workers, and amend those slightly as follows:
   1. Immediately after running HTTP-network-or-cache fetch:
      1. If response is a network error and response’s IP address space is non-null, then:
         1. Set request’s target IP address space to response’s IP address space.
         2. Return the result of running HTTP-no-service-worker fetch given fetchParams.
   2. NOTE: Because request’s target IP address space is set to a non-null value when recursing, this recursion can go at most 1 level deep.

\[TODO: Figure out what we need to add for cache fetch. A sketch of Chromium’s
behavior is included below in [S4.3 HTTP
Cache](https://docs.google.com/document/d/1k36kbb02YbYzQXJKKYj-bwL1LHZDI2g0MB8VTCjcPZk/edit?pli=1&resourcekey=0-e8EDkjUl_EAcj4kbTrEk7Q&tab=t.0#heading=h.nubaalxa7byn)
below.\]

NOTE: The requirement that local network requests be made from secure contexts
means that any insecure request will be blocked as mixed content unless we can
know ahead of time that the request should be considered a local network
request. By setting the target IP address space property (see Step 6i and 6ii
above), we only need to make a small change to Mixed Content \-- see Section
3.3. below.

#### **3.2.2. Fetch API**

The Fetch API needs to be adjusted as well.

* Append an optional [entry](https://infra.spec.whatwg.org/#map-entry) to [RequestInfo](https://fetch.spec.whatwg.org/#requestinfo), whose key is targetAddressSpace, and value is a [IPAddressSpace](https://wicg.github.io/private-network-access/#enumdef-ipaddressspace).
  partial dictionary [RequestInit](https://fetch.spec.whatwg.org/#requestinit) {  [IPAddressSpace](https://wicg.github.io/private-network-access/#enumdef-ipaddressspace) targetAddressSpace; };
* Define a new {=targetAddressSpace=} representing the above in [request](https://fetch.spec.whatwg.org/#fetch-params-request).
  partial interface [Request](https://fetch.spec.whatwg.org/#request) {  readonly attribute [IPAddressSpace](https://wicg.github.io/private-network-access/#enumdef-ipaddressspace) targetAddressSpace; };
* The [new Request(input, init)](https://fetch.spec.whatwg.org/#dom-request) is appended with the following step right before setting [this](https://webidl.spec.whatwg.org/#this)'s [request](https://fetch.spec.whatwg.org/#fetch-params-request) to request:
  1. If init\["[targetAddressSpace](https://wicg.github.io/private-network-access/#dom-requestinit-targetaddressspace)"\] [exists](https://infra.spec.whatwg.org/#map-exists), then switch on init\["[targetAddressSpace](https://wicg.github.io/private-network-access/#dom-requestinit-targetaddressspace)"\]:
     **public**
     Do nothing.
     **local**
     Set request’s [target IP address space](https://wicg.github.io/private-network-access/#request-target-ip-address-space) to local.

### 3.3. Integration with Mixed Content

The [Should fetching request be blocked as mixed
content?](https://w3c.github.io/webappsec-mixed-content/#should-block-fetch) is
amended to add the following condition to one of the **allowed** conditions:

1. request’s [origin](https://fetch.spec.whatwg.org/#concept-request-origin) is not a [potentially trustworthy origin](https://w3c.github.io/webappsec-secure-contexts/#potentially-trustworthy-origin), and request’s target IP address space is local.

The “[Upgrade request to an a priori authenticated URL as mixed content, if
appropriate](https://w3c.github.io/webappsec-mixed-content/level2.html#upgrade-algorithm)”
algorithm is amended to add the following condition as an exception from
upgrading in step 1:

6. `request`’s target IP address space is “`local”.`

### 3.4. Integration with WebSockets

WebSockets connections should be subject to the same local network access
permission requirements.

\[TODO: WebSockets “Obtain a WebSocket connection” is distinct, and a
“WebSocket connection” is also distinct. So strictly by spec we need to
duplicate some of our Fetch details but for WebSockets. See
[https://websockets.spec.whatwg.org/\#concept-websocket-connection-obtain](https://websockets.spec.whatwg.org/#concept-websocket-connection-obtain)\]

### 3.5 Integration with WebTransport

WebTransport connections should be subject to the same local network access
permission requirements.

### 3.6. Integration with HTML

To support the checks in \[[FETCH](https://fetch.spec.whatwg.org/)\], user
agents must remember the source IP address space of contexts in which network
requests are made. To this effect, the
\[[HTML](https://html.spec.whatwg.org/multipage/)\] specification is patched as
follows:

1. A new IP address space property is added to the [policy container](https://html.spec.whatwg.org/multipage/browsers.html#policy-container) [struct](https://infra.spec.whatwg.org/#struct).
   1. It is initially public.
2. An additional step is added to the [clone a policy container](https://html.spec.whatwg.org/multipage/browsers.html#clone-a-policy-container) algorithm:
   1. Set clone’s IP address space to policyContainer’s IP address space.
3. An additional step is added to the [create a policy container from a fetch response](https://html.spec.whatwg.org/multipage/browsers.html#creating-a-policy-container-from-a-fetch-response) algorithm:
   1. Set result’s IP address space to response’s IP address space.

EXAMPLE

Assuming that example.com resolves to a public address (say, 123.123.123.123),
then the [Document](https://html.spec.whatwg.org/#document) created when
navigating to https://example.com/document.html will have its [policy
container](https://html.spec.whatwg.org/multipage/dom.html#concept-document-policy-container)'s
IP address space property set to public.

If this [Document](https://html.spec.whatwg.org/#document) then embeds an
about:srcdoc iframe, then the child frame’s
[Document](https://html.spec.whatwg.org/#document) will have its [policy
container](https://html.spec.whatwg.org/multipage/dom.html#concept-document-policy-container)'s
IP address space property set to public.

If, on the other hand, example.com resolved to a loopback address (say,
127.0.0.1), then the [Document](https://html.spec.whatwg.org/#document) created
when navigating to https://example.com/document.html will have its [policy
container](https://html.spec.whatwg.org/multipage/dom.html#concept-document-policy-container)'s
[IP address
space](https://wicg.github.io/private-network-access/#policy-container-ip-address-space)
property set to local.

TODO: Also update the reference to Private Network Access in
[https://html.spec.whatwg.org/multipage/browsers.html\#coep](https://html.spec.whatwg.org/multipage/browsers.html#coep)

### 3.7. Workers

*This section is non-normative.*

Given that
[WorkerGlobalScope](https://html.spec.whatwg.org/multipage/workers.html#workerglobalscope)
already has a [policy
container](https://html.spec.whatwg.org/multipage/workers.html#concept-workerglobalscope-policy-container)
field populated using the [create a policy container from a fetch
response](https://html.spec.whatwg.org/multipage/browsers.html#creating-a-policy-container-from-a-fetch-response)
algorithm, the above integrations with Fetch and HTML apply just as well to
worker contexts as to documents.

Assuming that example.com resolves to a public address (say, 123.123.123.123),
then a
[WorkerGlobalScope](https://html.spec.whatwg.org/multipage/workers.html#workerglobalscope)
created by fetching a script from https://example.com/worker.js will have its
[policy
container](https://html.spec.whatwg.org/multipage/workers.html#concept-workerglobalscope-policy-container)'s
IP address space property set to public.

Any fetch [request](https://fetch.spec.whatwg.org/#fetch-params-request)
initiated by this worker that [obtains a
connection](https://fetch.spec.whatwg.org/#concept-connection-obtain) to an IP
address in the local address space would then be a local network request.

ISSUE: Chromium’s implementation currently applies the LNA permission for
service worker-initiated fetches based on the worker’s script origin (since
there may not be an active document around when the service worker is
executing). It may be better for this to be based on the partitioned storage
key of the worker, and it would also be good if permissions policy supported
service workers

ISSUE: The [Service
Worker](https://w3c.github.io/ServiceWorker/#dfn-service-worker) [soft
update](https://w3c.github.io/ServiceWorker/#soft-update) algorithm
unfortunately sets a [request
client](https://fetch.spec.whatwg.org/#concept-request-client) of "null" when
[fetching](https://fetch.spec.whatwg.org/#concept-fetch) an updated script.
This causes all sorts of issues, and interferes with the local network access
check algorithm laid out above. Indeed, there is no [request
client](https://fetch.spec.whatwg.org/#concept-request-client) from which to
copy the [policy
container](https://fetch.spec.whatwg.org/#concept-request-policy-container)
during [fetch](https://fetch.spec.whatwg.org/#concept-fetch). [\[Issue
\#83\]](https://github.com/wicg/private-network-access/issues/83)

## 4\. Implementation Considerations

### 4.1. Where do file URLs fit?

It isn’t entirely clear how file URLs fit into the public/local scheme outlined
above. It would be nice to prevent folks from harming themselves by opening a
malicious HTML file locally, on the one hand, but on the other, code running
locally is somewhat outside of any coherent threat model.

For the moment, let’s err on the side of treating file URLs as local, as they
seem to be just as much a part of the local system as anything else on a
loopback address.

 ISSUE: Re-evaluate this after implementation experience.

### 4.2. Proxies

In the current implementation of this specification in Chromium, proxies
influence the address space of resources they proxy. Specifically, resources
fetched via proxies are considered to have been fetched from the proxy’s IP
address itself.

If a [Document](https://html.spec.whatwg.org/#document) served by foo.example
on a public address is fetched by the user agent via a proxy on a local
address, then the [Document](https://html.spec.whatwg.org/#document)'s [policy
container](https://html.spec.whatwg.org/multipage/dom.html#concept-document-policy-container)'s
[IP address
space](https://wicg.github.io/private-network-access/#policy-container-ip-address-space)
is set to local.

The [Document](https://html.spec.whatwg.org/#document) will in turn be allowed
to make requests to other local addresses accessible to the browser.

This can allow a website to learn that it was proxied by observing that it is
allowed to make requests to private addresses, which is a privacy information
leak. While this requires correctly guessing the URL of a resource on the local
network, a single correct guess is sufficient.

This is expected to be relatively rare and not warrant more mitigations. After
all, in the status quo all websites can make requests to all IP addresses with
no restrictions whatsoever.

It would be interesting to explore a mechanism by which proxies could tell the
browser "please treat this resource as public/private anyway", thereby passing
on some information about the IP address behind the proxy.

### 4.3. HTTP Cache

The current implementation of this specification in Chromium interacts with the
HTTP cache in two noteworthy ways, depending on which kind of resource is
loaded from cache.

#### **4.3.1. Main resources**

A [document](https://dom.spec.whatwg.org/#concept-document) constructed from a
cached [response](https://fetch.spec.whatwg.org/#concept-response) remembers
the IP address from which the
[response](https://fetch.spec.whatwg.org/#concept-response) was initially
loaded. The IP address space of the
[document](https://dom.spec.whatwg.org/#concept-document) is derived anew from
the IP address.

In the common case, this entails that the
[document](https://dom.spec.whatwg.org/#concept-document)'s [policy
container](https://html.spec.whatwg.org/multipage/dom.html#concept-document-policy-container)'s
IP address space is restored unmodified. However in the event that the user
agent’s configuration has changed, the derived IP address space might be
different.

EXAMPLE

The user agent navigates to http://foo.example/, loads the main resource from
1.2.3.4, caches it, then sets the resulting
[document](https://dom.spec.whatwg.org/#concept-document)'s [policy
container](https://html.spec.whatwg.org/multipage/dom.html#concept-document-policy-container)'s
IP address space to public.

The user agent then restarts, and a new configuration is applied specifying
that 1.2.3.4 should be classified as a local address instead.

The user agent navigates to http://foo.example/ once more and loads the main
resource from the HTTP cache. The resulting
[document](https://dom.spec.whatwg.org/#concept-document)'s [policy
container](https://html.spec.whatwg.org/multipage/dom.html#concept-document-policy-container)'s
IP address space is now set to local.

#### **4.3.2. Subresources**

Subresources loaded from the HTTP cache are subject to the Local Network Access
check. This is not yet reflected in the algorithms above, since that check is
only applied in [HTTP-network
fetch](https://fetch.spec.whatwg.org/#concept-http-network-fetch).

TODO: Specify and explain Chromium’s behavior here, or add an
[HTTP-network-or-cache
fetch](https://fetch.spec.whatwg.org/#http-network-or-cache-fetch) integration
above. [\[Issue
\#75\]](https://github.com/wicg/private-network-access/issues/75) We include a
sketch below.

As with main resources, a subresource constructed from a cached response
remembers the IP address from which the response was initially loaded. The IP
address space of the response is derived anew from the IP address.

In the common case, this entails that the response’s IP address space is
restored unmodified. However, in the event that the user agent’s configuration
has changed, the derived IP address space might be different.

When a subresource request is blocked by LNA checks (i.e., the permission was
denied), there is no resource response cached. If the permission is later reset
or granted, the subresource request will go to the network.

EXAMPLE 1: Previously allowed subresource load

The user agent navigates to https://foo.example, which is loaded from 1.2.3.4
(which has an IP address space of `public`). The document triggers a
subresource request for
[http://bar.local/image.jpg](http://bar.local/image.jpg), which when a
connection is created has an IP address of 10.0.1.1 (which has an IP address
space of `local`). This triggers a permission prompt, granting the Local
Network Access permission to https://foo.example, and then the subresource is
loaded and added to the user agent’s cache.

The user agent resets the permission for
[https://foo.example](https://foo.example).

The user agent navigates to [https://foo.example](https://foo.example) once
more, which once again triggers a subresource request for
[http://bar.local/image.jpeg](http://bar.local/image.jpeg). This resource is in
the user agent’s cache, with a cached response IP address of 10.0.1.1. This
again triggers a permission prompt, which if granted will finish loading the
resource from the user agent’s cache.

EXAMPLE 2: Previously blocked subresource load

The user agent navigates to https://foo.example, which is loaded from 1.2.3.4
(which has an IP address space of `public`). The document triggers a
subresource request for
[http://bar.local/image.jpg](http://bar.local/image.jpg), which when a
connection is created has an IP address of 10.0.1.1 (which has an IP address
space of `local`). This triggers a permission prompt, denying the Local Network
Access permission to [https://foo.example](https://foo.example). The
subresource request is blocked and no resource is added to the user agent’s
cache.

The user agent resets the permission for
[https://foo.example](https://foo.example).

The user agent navigates to [https://foo.example](https://foo.example) once
more, which once again triggers a subresource request for
[http://bar.local/image.jpeg](http://bar.local/image.jpeg). This resource is
not in the user agent’s cache, so goes through HTTP network fetch and triggers
the permission prompt.

See [§ 5.6 HTTP
cache](https://wicg.github.io/private-network-access/#http-cache-security) for
a discussion of security implications.

### 4.4. Rollout difficulties

Local Network Access essentially deprecates direct access to the local network
in favor of more secure user-agent-mediated alternatives. Web deprecations are
hard. Chromium previously encountered many stumbling blocks on the way to
shipping parts of Private Network Access (the predecessor to this
specification).

In particular, shipping restrictions on fetches from [non-secure
contexts](https://html.spec.whatwg.org/multipage/webappapis.html#non-secure-context)
in the local IP address space to services on `localhost` have proven
particularly difficult, for a lower payoff. Indeed, exploiting such fetches
requires attackers to already have a foothold in the private network, which
substantially raises attack difficulty. As a result, Chromium is exempting
these fetches from restrictions temporarily, choosing to focus on fetches from
the public IP address space. See [S5.5 Local network
attackers](https://docs.google.com/document/d/1k36kbb02YbYzQXJKKYj-bwL1LHZDI2g0MB8VTCjcPZk/edit?pli=1&resourcekey=0-e8EDkjUl_EAcj4kbTrEk7Q&tab=t.0#heading=h.cymi48yxhk1z)
for a discussion of security implications.

## 5\. Security and Privacy Considerations

### 5.1. User Mediation

The proposal in this document only ensures that the user consents to access
from the public internet. This proposal does not allow for devices to
explicitly approve for connections from the public internet.

An alternative model where devices had to explicitly approve for connections
from the public internet was attempted in Private Network Access, but ran into
rollout difficulties. TODO link to some rollout difficulties of PNA

### 5.2. DNS Rebinding

The mitigation described here operates upon the IP address which the user agent
actually connects to when loading a particular resource. This check MUST be
performed for each new connection made, as DNS rebinding attacks may otherwise
trick the user agent into revealing information it shouldn’t.

DNS rebinding attacks also mean that local network access checks MUST apply to
all `public` to `local` requests (that is, we cannot simplify the algorithm to
be “any cross-origin request to a `local` endpoint”, as this would open a risk
of a user navigation to a.example, then moving networks or having DNS change to
make a.example point to a local address).

### 5.3. Scope of Mitigation

The proposal in this document merely mitigates attacks against local web
services, it cannot fully solve them. For example, a router’s web-based
administration interface must be designed and implemented to defend against
CSRF on its own, and should not rely on a UA that behaves as specified in this
document. The mitigation this document specifies is necessary given the reality
of local web service implementation quality today, but vendors should not
consider themselves absolved of responsibility, even if all UAs implement this
mitigation.

### 5.4. Cross-network confusion

Most local networks cannot communicate with each other, yet they are all
treated by this specification as belonging to the local IP address space. Going
further, local addresses have meaning only on the local network where they are
used. The same IP address might refer to entirely different devices in two
different networks. A user granting permission for a.example to make local
network requests could then move to a different network, and then a.example
would continue to be able to make local network requests.

This opens the door to cross-network attacks:

*   A user connects to two different local networks: a home Wi-Fi network and a corporate VPN. Their smart fridge has been hacked. They open their smart fridge’s web interface, which then performs CSRF attacks against corporate websites accessible via the VPN.

* A user connects to a malicious internet cafe Wi-Fi, which requires users to keep a captive portal page open. They close their laptop, go home, open up their laptop again. The captive portal page (either still open or reloaded from cache as the user agent restores its previous state) performs CSRF attacks against the user’s home devices.

* A user connects to a malicious internet cafe Wi-Fi, whose captive portal website caches a malicious script from http://router.example/popular-library.js (the cafe network administrator operates a malicious DNS server) with a very long expiry. The user powers their computer off, goes home, boots up their computer again and visits their router’s administration interface at http://router.example, which embeds /popular-library.js. The malicious script is loaded in the administration interface’s first-party context.

None of these attacks are novel \- they are just examples of the limitations of this specification.

ISSUE: Potential mitigations would require noticing network changes and
clearing state specific to the previous network. Doing so in a fully general
manner is likely to be impossible short of clearing all state. Maybe a
practical compromise can be reached. [\[PNA Issue
\#28\]](https://github.com/wicg/private-network-access/issues/28)

An alternative approach might be to scope the permission grant to an identifier
that distinguishes different networks.

### 5.5. Local network attackers

Until local network access checks are applied to all cross-origin requests to
the `local` address space, it is possible for a malicious server on the local
network to (1) attack other servers on the local network, and (2) attack
services running on `localhost` on a user’s machine. (1) is already possible
without needing to abuse the user’s browser, but (2) remains a concern. For
example, a captive portal might be able to redirect the user to a malicious
page that tries to probe and attack vulnerable `localhost` services running on
the user’s machine. (See also [PNA Issue
\#39](https://github.com/wicg/private-network-access/issues/39).)

We see public websites on the drive-by web as a more urgent security (and
privacy) risk and see an incremental rollout of these protections as valuable
progress, despite the lingering risk from local network attackers.

### 5.6. HTTP cache

#### **5.6.1. Applying checks to subresources**

Cached subresources are protected by this specification, as the HTTP cache
remembers the source IP address which can be used in the Local Network Access
check algorithm during [HTTP-network-or-cache
fetch](https://fetch.spec.whatwg.org/#concept-http-network-or-cache-fetch).

Without this check, a malicious public website might be able to determine
whether a user has visited particular private websites in the past.

Due to HTTP cache partitioning, a subresource can only be loaded from cache by
malicious attackers who manage to replicate the [network partition
key](https://fetch.spec.whatwg.org/#network-partition-key) of the [cache
entry](https://fetch.spec.whatwg.org/#cache-entry). One way an attacker could
achieve this is by manipulating DNS (see also [§ 5.3 DNS
Rebinding](https://wicg.github.io/private-network-access/#dns-rebinding)) in
order to impersonate the top-level site that initially embedded the cached
resource.

The user agent navigates to http://router.example, which is served from
192.168.1.1. The website embeds a logo from
http://router.example/$BRAND-logo.png, which is cached.

A malicious attacker then re-binds router.example to an attacker-controlled
public IP address, and somehow tricks the user into visiting
http://router.example again. The malicious website attempts to embed the logo,
and monitors whether the load is successful. If so, the attacker has determined
the brand of the user’s router.

#### **5.6.2. HTTP cache poisoning**

While this specification aims to protect local network servers from receiving
requests from public websites, DNS rebinding can be used to carry out a similar
attack through cache poisoning of unauthenticated resources.

Attackers masquerading as http://router.com can cache a malicious script at
http://router.com/totally-legit.js. Later on, when the user navigates to
http://router.com/, the page might request the poisoned script and execute
attacker code in a [less
public](https://wicg.github.io/private-network-access/#ip-address-space-less-public)
[IP address
space](https://wicg.github.io/private-network-access/#ip-address-space).

This attack is partially mitigated by cache partitioning, which makes it so
that the attacker must navigate a top-level browsing context to
http://router.com/ before caching resources, which lacks subtlety. It is also
not specific to Local Network Access, rather being a symptom of plaintext
HTTP’s lack of authentication and integrity protection.

## 7\. Acknowledgements

Many thanks for valuable feedback and advice from Titouan Rigoudy, Jonathan
Hao, and Yifan Luo who worked on the original Private Network Access proposals
and specification, and generously discussed their work and helped brainstorm
paths forward.

## IDL Index

enum IPAddressSpace { "public", "local" };

dictionary LocaNetworkAccessPermissionDescriptor
    : [PermissionDescriptor](https://w3c.github.io/permissions/#dom-permissiondescriptor) {
  [DOMString](https://webidl.spec.whatwg.org/#idl-DOMString) id;
};

partial dictionary [RequestInit](https://fetch.spec.whatwg.org/#requestinit) {
  IPAddressSpace targetAddressSpace;
};

partial interface [Request](https://fetch.spec.whatwg.org/#request) {
  readonly attribute IPAddressSpace targetAddressSpace;
};

