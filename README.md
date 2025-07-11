# Linux Dev Server

A remote development server running on Fly.io with SSH access and persistent storage. Essentially, we're copying our Ubuntu files into persistent storage volume we chroot into, to persist changes.


### Initial Setup


1. **Generate SSH keys for the dev server**
   ```bash
   # Generate a new SSH key pair specifically for this dev server
   ssh-keygen -t ed25519 -f ~/.ssh/fly_dev_server -C "fly-dev-server"
   
   # Copy the public key to the authorized_keys file in the project
   cp ~/.ssh/fly_dev_server.pub authorized_keys
   ```

2. **Create the Fly app**
   ```bash
   fly apps create YOUR-APP-NAME
   ```

3. **Create a persistent volume** (for storing data between deployments)
   ```bash
   fly volumes create data --size 10 --region YOUR-REGION
   ```
   Replace `YOUR-REGION` with your preferred region (e.g., `sjc`, `ord`, `lhr`)

4. **Deploy the app**
   ```bash
   fly deploy
   ```

5. **Get the app's IPv6 address**
   ```bash
   fly ips list
   ```

6. **Configure SSH client**
   Add to your `~/.ssh/config`:
   ```
   Host fly-dev
       HostName YOUR-APP-NAME.fly.dev
       User root
       Port 22
       IdentityFile ~/.ssh/fly_dev_server
       StrictHostKeyChecking no
       UserKnownHostsFile /dev/null
   ```

7. **Connect via SSH**
   ```bash
   # Using the SSH config
   ssh fly-dev
   
   # Or directly
   ssh -i ~/.ssh/fly_dev_server root@YOUR-APP-NAME.fly.dev
   ```
