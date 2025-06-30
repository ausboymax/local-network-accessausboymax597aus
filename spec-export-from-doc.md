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

