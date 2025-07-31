# Security and Privacy Self-Review: Local Network Access

Based on the W3C TAG's
[questionnaire](https://www.w3.org/TR/security-privacy-questionnaire/).

### 1\. What information does this feature expose, and for what purposes?

Documents might be able to infer whether they were loaded from `public`, `local`
or `loopback` IP address by observing whether they can successfully load a
well-known subresource from the local network or localhost. This is largely
unavoidable by design: this specification aims to alter user agent behavior
differentially based on the IP address which served the main resource.

This can also arise when a client loaded a resource over a non-public proxy,
such as:

  * an ssh tunnel
  * a network inspection tool such as [Fiddler](https://telerik.com/fiddler)
  * a corporate proxy

### 2\. Do features in your specification expose the minimum amount of information necessary to implement the intended functionality?

Yes, apart from the above.

### 3\. Do the features in your specification expose personal information, personally-identifiable information (PII), or information derived from either?

No.

### 4\. How do the features in your specification deal with sensitive information?

No.

### 5\. Does data exposed by your specification carry related but distinct information that may not be obvious to users?

No.

### 6\. Do the features in your specification introduce state that persists across browsing sessions?

We introduce a new permission type, and some browsers persist permission grants
across browsing sessions. We also include the IP address space a response was
loaded from as part of caching a response. No other potentially persistent state
is introduced.

### 7\. Do the features in your specification expose information about the underlying platform to origins?

See Question 1.

### 8\. Does this specification allow an origin to send data to the underlying platform?

No, instead it restricts the ability of origins to send requests to the local
device.

### 9\. Do features in this specification enable access to device sensors?

No.

### 10\. Do features in this specification enable new script execution/loading mechanisms?

No.

### 11\. Do features in this specification allow an origin to access other devices?

No, instead it restricts the ability of origins to access local network devices.

### 12\. Do features in this specification allow an origin some measure of control over a user agent’s native UI?

No.

### 13\. What temporary identifiers do the features in this specification create or expose to the web?

None.

### 14\. How does this specification distinguish between behavior in first-party and third-party contexts?

Third-party iframes are treated distinctly from the first-party embedder: even
if the first-party is served from non-public address space, only the
third-party's address space is considered when applying local network request
checks to requests made by the third-party iframe.

Third-party scripts are not treated distinctly. There seems to be no particular
reason to treat third-party scripts differently when checking outgoing requests,
however.

One area of discussion is whether or not to treat sandboxed iframes as `public`:
see
[WICG/prvate-network-access\#26](https://github.com/WICG/private-network-access/issues/26).
It seems a good idea to do so, enabling web developers to include third-party
content on non-public websites without allowing it to poke at non-public
resources. On the other hand, this might help malicious websites trying to
determine which IP address they are being accessed from by providing them with a
baseline against which to compare their own capabilities.

### 15\. How do the features in this specification work in the context of a browser’s Private Browsing or Incognito mode?

It works the same. We do note that different browsers may choose to not share
permission state between regular browsing modes and private browsing modes.

### 16\. Does this specification have both "Security Considerations" and "Privacy Considerations" sections?

Yes.

### 17\. Do features in your specification enable origins to downgrade default security protections?

Yes. Because our specification requires a secure context in order to make local
network requests, this creates a conundrum as many local servers do not support
HTTPS with publicly trusted certificates. This chicken-and-egg problem means
that if a site upgrades to HTTPS to meet the secure contexts requirement, these
local network requests would then be blocked as mixed content. To work around
this, our specification lays out certain special cased exemptions to mixed
content upgrading and blocking such that these local requests can still be
performed: (1) `fetch()` calls that are explicitly tagged with the
`targetAddressSpace` option, (2) requests to local IP address literals, and (3)
requests to `.local` domains. To prevent these from being abusable as a general
bypass of mixed content restrictions, we additionally check that these requests
actually end up going to the local network -- if after resolving the hostname
their resulting address space does not match we block them.

However, in the status quo sites that need to make connections to local network
devices that only support HTTP simply choose to not support HTTPS at all in
order to avoid these connections being blocked as mixed content. In this regard,
we believe having some exceptions to mixed content rules but having more sites
able to use HTTPS is a net positive.

### 18\. What happens when a document that uses your feature is kept alive in BFCache (instead of getting destroyed) after navigation, and potentially gets reused on future navigations back to the document?

There are no specific interactions between our feature and BFCache. The IP
address space on the policy container would be kept and reused (e.g., a page
that ended up being fetched from a public address would continue to be
considered public after being restored from BFCache), similar to how we
reconstruct address space state for resources loaded from cache.

### 19\. What happens when a document that uses your feature gets disconnected?

If a frame becomes disconnected it can no longer request or use the LNA
permission, as it is no longer in a frame tree that can reach a top level
document context in which permissions can be granted and delegated via
permisison policy.

On becoming connected again, the frame would be reloaded and its LNA policy and
address space would either be recomputed fresh or taken from cache, as expected.

### 20\. Does your spec define when and how new kinds of errors should be raised?

No, our spec does not add any new kinds of errors. We raise network errors in
our Fetch integration when local network access checks fail.

### 21\. Does your feature allow sites to learn about the user’s use of assistive technology?

No.

### 22\. What should this questionnaire have asked?

None that we can think of :-)
