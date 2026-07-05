# Creating an AWS ACM Certificate (Cloudflare DNS)

To create an AWS Certificate Manager (ACM) certificate for your project using a domain managed by Cloudflare, you need to request the certificate in AWS and then add a specific DNS validation record into Cloudflare.

Before jumping into the steps, there is a **critical architectural rule** to keep in mind regarding ACM:

> ⚠️ **Important Note on ACM Certificates:** ACM certificates **cannot** be downloaded as files (like `.crt` or `.key`) to be placed inside a Docker container or directly onto an EC2 instance. They can only be attached to AWS-managed resources like an **Application Load Balancer (ALB)**, **CloudFront distribution**, or **API Gateway**. If your `misp-production` setup uses an ALB or CloudFront in front of it, ACM is the perfect choice. If you are running Docker directly on a single EC2 instance without a load balancer, you should use **Let's Encrypt (Certbot)** instead of ACM.

Assuming you are using an AWS Load Balancer or CloudFront in front of your MISP instance, here is the step-by-step guide to creating and validating your ACM certificate.

---

## Step 1: Request the Certificate in AWS ACM

1. Log into your **AWS Management Console**.
2. **Select your Region:** Ensure you are in the correct AWS region.
   * If you are attaching this certificate to an **Application Load Balancer (ALB)**, select the exact region where your project is being deployed (e.g., `us-east-1`, `eu-west-1`).
   * If you plan to use **AWS CloudFront**, you *must* switch your region to **us-east-1 (N. Virginia)**, as CloudFront requires ACM certificates to live there.
3. Search for and open **Certificate Manager**.
4. Click **Request a certificate**, select **Request a public certificate**, and click **Next**.
5. Fill in the domain configuration:
   * **Fully qualified domain name:** Enter the subdomain you intend to use for MISP (e.g., `misp.kravensecurity.com`) or use a wildcard if you want it to cover multiple services (e.g., `*.kravensecurity.com`).
   * **Validation method:** Select **DNS validation** (Recommended).
   * **Key algorithm:** `RSA 2048` (standard and widely compatible).
6. Click **Request**.

---

## Step 2: Retrieve the DNS Validation Records

1. Once requested, you will see a screen showing your certificates. Click on your newly requested certificate ID (it will state **Pending validation**).
2. Under the **Domains** section, look for the table containing **CNAME name** and **CNAME value**.
3. Copy both the **CNAME name** and **CNAME value** strings. You will need these for Cloudflare.

---

## Step 3: Add the CNAME Record to Cloudflare

1. Log into your **Cloudflare Dashboard** and select your domain `kravensecurity.com`.
2. Go to **DNS** > **Records** on the left-hand sidebar.
3. Click **Add record** and configure it as follows:
   * **Type:** `CNAME`
   * **Name:** Paste the **CNAME name** provided by AWS.
     *(Note: AWS gives you the full string like `_x2.misp.kravensecurity.com.`. Cloudflare is smart—if you paste the whole thing, it will automatically strip your root domain out and leave just the host section, which is correct).*
   * **Target:** Paste the exact **CNAME value** provided by AWS (e.g., `_x3.acm-validations.aws.`).
   * **Proxy status:** 🛑 **DNS Only (Grey Cloud)**. This is the most crucial step! If you leave it as *Proxied (Orange Cloud)*, AWS's validation servers will hit Cloudflare's edge proxy instead of reading the raw validation record, and your certificate will remain stuck in pending indefinitely.
4. Click **Save**.

---

## Step 4: Wait for Validation

AWS continuously polls for this record. Now that Cloudflare is serving the grey-clouded CNAME record, AWS will usually discover it within 2 to 10 minutes.

Refresh your AWS ACM console page. The status will update from **Pending validation** to **Issued**.

---

## Step 5: Connecting Your Main Traffic (Optional Tip)

Once the certificate is **Issued**, you can attach it to your AWS Application Load Balancer's HTTPS listener (Port 443).

When you create the actual DNS record pointing traffic from `misp.kravensecurity.com` to your AWS Load Balancer URL:

1. You can safely keep that record **Proxied (Orange Cloud)** in Cloudflare to benefit from Cloudflare's DDoS protection and WAF.
2. In Cloudflare, make sure your **SSL/TLS encryption mode** is set to **Full** or **Full (strict)**. This ensures that the traffic between Cloudflare and your AWS Load Balancer remains entirely encrypted using the ACM certificate you just stood up.
