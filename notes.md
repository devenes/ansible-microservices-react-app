# Ansible Project Solution

- Create ansible directory and change directory to this directory.

```bash
mkdir ansible
cd ansible
```

- Create `ansible.cfg`

```
[defaults]
host_key_checking = False
inventory=inventory_aws_ec2.yml
interpreter_python=auto_silent
private_key_file=/home/ec2-user/keyname.pem
remote_user=ec2-user
```

- copy pem file from local to home directory of ec2-user.

```bash
scp -i keyname.pem keyname.pem ec2-user@<public-ip of ansible_control>:/home/ec2-user
```

## Creating dynamic inventory

- Create `inventory_aws_ec2.yml` file under the ansible directory.

```yaml
plugin: aws_ec2
regions:
  - "us-east-1"
filters:
  tag:stack: ansible_project
keyed_groups:
  - key: tags.Name
  - key: tags.environment
compose:
  ansible_host: public_ip_address
```

```bash
ansible-inventory -i inventory_aws_ec2.yml --graph
```

- Output will be like below.

  ```
  @all:
    |--@_ansible_control:
    |  |--ec2-3-80-96-146.compute-1.amazonaws.com
    |--@ansible_nodejs:
    |  |--ec2-3-239-243-194.compute-1.amazonaws.com
    |--@ansible_postgresql:
    |  |--ec2-3-236-160-236.compute-1.amazonaws.com
    |--@ansible_react:
    |  |--ec2-3-236-197-117.compute-1.amazonaws.com
    |--@development:
    |  |--ec2-3-236-160-236.compute-1.amazonaws.com
    |  |--ec2-3-236-197-117.compute-1.amazonaws.com
    |  |--ec2-3-239-243-194.compute-1.amazonaws.com
    |--@aws_ec2:
    |  |--ec2-3-236-160-236.compute-1.amazonaws.com
    |  |--ec2-3-236-197-117.compute-1.amazonaws.com
    |  |--ec2-3-239-243-194.compute-1.amazonaws.com
    |  |--ec2-3-80-96-146.compute-1.amazonaws.com
    |--@ungrouped:
  ```

- To make sure that all our hosts are reachable with dynamic inventory, we will run various ad-hoc commands that use the ping module.

```bash
ansible all -m ping --key-file "~/keyname.pem"
```

## Prepare the playbook files

- Create `ansible-servers` directory under home directory and change directory to this directory.

```bash
mkdir ansible-servers
cd ansible-servers
```

- Create `postgres`, `nodejs`, `react` directories.

```bash
mkdir postgres nodejs react
```

- Copy `~/student_files/todo-app-pern` directory to this directory.

- Change directory to `postgres` directory.

```bash
cd postgres
```

- Copy `init.sql` file from `student_files/todo-app-pern/database` to `postgres` directory.

- Create a Dockerfile

```Dockerfile
FROM postgres

COPY ./init.sql /docker-entrypoint-initdb.d/

EXPOSE 5432
```

- change directory `~/ansible` directory.

```bash
cd ~/ansible
```

- Create a yaml file as postgres playbook and name it `docker_postgre.yml`

```yaml
- name: Install docker
  gather_facts: No
  any_errors_fatal: true
  hosts: ansible_postgresql
  become: true
  tasks:
    - name: upgrade all packages
      yum:
        name: "*"
        state: latest
    # we may need to uninstall any existing docker files from the centos repo first.
    - name: Remove docker if installed from CentOS repo
      yum:
        name: "{{ item }}"
        state: removed
      with_items:
        - docker
        - docker-client
        - docker-client-latest
        - docker-common
        - docker-latest
        - docker-latest-logrotate
        - docker-logrotate
        - docker-engine
    - name: Install yum utils
      yum:
        name: "{{ item }}"
        state: latest
      with_items:
        - yum-utils
    # yum-utils is a collection of tools and programs for managing yum repositories, installing debug packages, source packages, extended information from repositories and administration.
    - name: Add Docker repo
      get_url:
        url: https://download.docker.com/linux/centos/docker-ce.repo
        dest: /etc/yum.repos.d/docker-ce.repo
    - name: Install Docker
      package:
        name: docker-ce
        state: latest
    - name: Install pip
      package:
        name: python3-pip
        state: present
        update_cache: true
    - name: Install docker sdk
      pip:
        name: docker
    - name: Add user ec2-user to docker group
      user:
        name: ec2-user
        groups: docker
        append: yes
    - name: Start Docker service
      service:
        name: docker
        state: started
        enabled: yes
    - name: create build directory
      file:
        path: /home/ec2-user/postgresql
        state: directory
        owner: root
        group: root
        mode: "0755"
    - name: copy the sql script
      copy:
        src: /home/ec2-user/ansible-servers/postgres/init.sql
        dest: /home/ec2-user/postgresql
    - name: copy the Dockerfile
      copy:
        src: /home/ec2-user/ansible-servers/postgres/Dockerfile
        dest: /home/ec2-user/postgresql
    - name: remove enes_postgre container and devenes/postgre if exists
      shell: "docker ps -q --filter 'name=enes_postgre' && docker stop enes_postgre && docker rm -fv enes_postgre && docker image rm -f devenes/postgre || echo 'Not Found'"
    - name: build container image
      docker_image:
        name: devenes/postgre
        build:
          path: /home/ec2-user/postgresql
        source: build
        state: present
    - name: Launch postgresql docker container
      docker_container:
        name: enes_postgre
        image: devenes/postgre
        state: started
        ports:
          - "5432:5432"
        env:
          POSTGRES_PASSWORD: "Pp123456789"
        volumes:
          - /custom/mount:/var/lib/postgresql/data
      register: container_info
    - name: Print the container_info
      debug:
        msg: "{{ container_info }}"
```

- Execute it.

```
ansible-playbook docker_postgre.yml
```

- Change directory to `~/ansible-servers/nodejs` directory.

```bash
cd ~/ansible-servers/nodejs
```

- Create a `Dockerfile`

```Dockerfile
FROM node:14-alpine

# Create app directory
WORKDIR /usr/src/app


COPY package*.json ./

RUN npm install
# If you are building your code for production
# RUN npm ci --only=production


# copy all files into the image
COPY . .

EXPOSE 5000

CMD ["node","app.js"]
```

- Change the `~/ansible-servers/todo-app-pern/server/.env` file as below.

```
SERVER_PORT=5000
DB_USER=postgres
DB_PASSWORD=Pp123456789
DB_NAME=enestodo
DB_HOST=************ # (private ip of postgresql instance)
DB_PORT=5432
```

- change directory `~/ansible` directory.

```bash
cd ~/ansible
```

- Create a yaml file as nodejs playbook and name it `docker_nodejs.yml`

```yaml
- name: Install docker
  gather_facts: No
  any_errors_fatal: true
  hosts: ansible_nodejs
  become: true
  tasks:
    - name: upgrade all packages
      yum:
        name: "*"
        state: latest
    # we may need to uninstall any existing docker files from the centos repo first.
    - name: Remove docker if installed from CentOS repo
      yum:
        name: "{{ item }}"
        state: removed
      with_items:
        - docker
        - docker-client
        - docker-client-latest
        - docker-common
        - docker-latest
        - docker-latest-logrotate
        - docker-logrotate
        - docker-engine
    - name: Install yum utils
      yum:
        name: "{{ item }}"
        state: latest
      with_items:
        - yum-utils
    - name: Add Docker repo
      get_url:
        url: https://download.docker.com/linux/centos/docker-ce.repo
        dest: /etc/yum.repos.d/docker-ce.repo
    - name: Install Docker
      package:
        name: docker-ce
        state: latest
    - name: Install pip
      package:
        name: python3-pip
        state: present
        update_cache: true
    - name: Install docker sdk
      pip:
        name: docker
    - name: Add user ec2-user to docker group
      user:
        name: ec2-user
        groups: docker
        append: yes
    - name: Start Docker service
      service:
        name: docker
        state: started
        enabled: yes
    - name: create build directory
      file:
        path: /home/ec2-user/nodejs
        state: directory
        owner: root
        group: root
        mode: "0755"
    # at this point do not forget change DB_HOST env variable for postgresql node
    - name: copy files to the nodejs node
      copy:
        src: /home/ec2-user/ansible-servers/todo-app-pern/server/
        dest: /home/ec2-user/nodejs
    - name: copy the Dockerfile
      copy:
        src: /home/ec2-user/ansible-servers/nodejs/Dockerfile
        dest: /home/ec2-user/nodejs
    - name: remove enes_nodejs container if exists
      shell: "docker ps -q --filter 'name=enes_nodejs' && docker stop enes_nodejs && docker rm -fv enes_nodejs && docker image rm devenes/nodejs || echo 'Not Found'"
    - name: build container image
      docker_image:
        name: devenes/nodejs
        build:
          path: /home/ec2-user/nodejs
        source: build
        state: present
    - name: Launch postgresql docker container
      docker_container:
        name: enes_nodejs
        image: devenes/nodejs
        state: started
        ports:
          - "5000:5000"
      register: container_info
    - name: Print the container_info
      debug:
        msg: "{{ container_info }}"
```

- Execute it.

```
ansible-playbook docker_nodejs.yml
```

- Change directory to `~/ansible-servers/react` directory.

```bash
cd ~/ansible-servers/react
```

- Create a `Dockerfile`

```Dockerfile
FROM node:14-alpine

# Create app directory
WORKDIR /app


COPY package*.json ./

RUN yarn install

# copy all files into the image
COPY . .

EXPOSE 3000

CMD ["yarn", "run", "start"]
```

- Change the `~/ansible-servers/todo-app-pern/client/.env` file as below.

```
REACT_APP_BASE_URL=http://<public ip of nodejs>:5000/
```

- change directory `~/ansible` directory.

```bash
cd ~/ansible
```

- Create a yaml file as react playbook and name it `docker_react.yml`

```yaml
- name: Install docker
  gather_facts: No
  any_errors_fatal: true
  hosts: ansible_react
  become: true
  tasks:
    - name: upgrade all packages
      yum:
        name: "*"
        state: latest
    # we may need to uninstall any existing docker files from the centos repo first.
    - name: Remove docker if installed from CentOS repo
      yum:
        name: "{{ item }}"
        state: removed
      with_items:
        - docker
        - docker-client
        - docker-client-latest
        - docker-common
        - docker-latest
        - docker-latest-logrotate
        - docker-logrotate
        - docker-engine
    - name: Install yum utils
      yum:
        name: "{{ item }}"
        state: latest
      with_items:
        - yum-utils
    - name: Add Docker repo
      get_url:
        url: https://download.docker.com/linux/centos/docker-ce.repo
        dest: /etc/yum.repos.d/docker-ce.repo
    - name: Install Docker
      package:
        name: docker-ce
        state: latest
    - name: Install pip
      package:
        name: python3-pip
        state: present
        update_cache: true
    - name: Install docker sdk
      pip:
        name: docker
    - name: Add user ec2-user to docker group
      user:
        name: ec2-user
        groups: docker
        append: yes
    - name: Start Docker service
      service:
        name: docker
        state: started
        enabled: yes
    - name: create build directory
      file:
        path: /home/ec2-user/react
        state: directory
        owner: root
        group: root
        mode: "0755"
    # at this point do not forget change DB_HOST env variable for postgresql node
    - name: copy files to the nodejs node
      copy:
        src: /home/ec2-user/ansible-servers/todo-app-pern/client/
        dest: /home/ec2-user/react
    - name: copy the Dockerfile
      copy:
        src: /home/ec2-user/ansible-servers/react/Dockerfile
        dest: /home/ec2-user/react
    - name: remove enes_react container and devenes/react image if exists
      shell: "docker ps -q --filter 'name=enes_react' && docker stop enes_react && docker rm -fv enes_react && docker image rm -f devenes/react || echo 'Not Found'"
    - name: build container image
      docker_image:
        name: devenes/react
        build:
          path: /home/ec2-user/react
        source: build
        state: present
    - name: Launch react docker container
      docker_container:
        name: enes_react
        image: devenes/react
        state: started
        ports:
          - "3000:3000"
      register: container_info
    - name: Print the container_info
      debug:
        msg: "{{ container_info }}"
```

- Execute it.

```
ansible-playbook docker_react.yml
```

## Prepare one playbook file for all instances.

- Create a `docker_project.yaml` file under `the ~/ansible` folder.

```yaml
- name: Docker install and configuration
  gather_facts: No
  any_errors_fatal: true
  hosts: development
  become: true
  tasks:
    - name: upgrade all packages
      yum:
        name: "*"
        state: latest
    # we may need to uninstall any existing docker files from the centos repo first.
    - name: Remove docker if installed from CentOS repo
      yum:
        name: "{{ item }}"
        state: removed
      with_items:
        - docker
        - docker-client
        - docker-client-latest
        - docker-common
        - docker-latest
        - docker-latest-logrotate
        - docker-logrotate
        - docker-engine
    - name: Install yum utils
      yum:
        name: "{{ item }}"
        state: latest
      with_items:
        - yum-utils
    - name: Add Docker repo
      get_url:
        url: https://download.docker.com/linux/centos/docker-ce.repo
        dest: /etc/yum.repos.d/docker-ce.repo
    - name: Install Docker
      package:
        name: docker-ce
        state: latest
    - name: Install pip
      package:
        name: python3-pip
        state: present
        update_cache: true
    - name: Install docker sdk
      pip:
        name: docker
    - name: Add user ec2-user to docker group
      user:
        name: ec2-user
        groups: docker
        append: yes
    - name: Start Docker service
      service:
        name: docker
        state: started
        enabled: yes

- name: Postgre Database configuration
  hosts: ansible_postgresql
  become: true
  gather_facts: No
  any_errors_fatal: true
  vars:
    postgre_home: /home/ec2-user/ansible-servers/postgres
    postgre_container: /home/ec2-user/postgresql
    container_name: enes_postgre
    image_name: devenes/postgre
  tasks:
    - name: create build directory
      file:
        path: "{{ postgre_container }}"
        state: directory
        owner: root
        group: root
        mode: "0755"
    - name: copy the sql script
      copy:
        src: /home/ec2-user/ansible-servers/postgres/init.sql
        dest: "{{ postgre_container }}"
    - name: copy the Dockerfile
      copy:
        src: /home/ec2-user/ansible-servers/postgres/Dockerfile
        dest: "{{ postgre_container }}"
    - name: remove {{ container_name }} container and {{ image_name }} if exists
      shell: "docker ps -q --filter 'name={{ container_name }}' && docker stop {{ container_name }} && docker rm -fv {{ container_name }} && docker image rm -f {{ image_name }} || echo 'Not Found'"
    - name: build container image
      docker_image:
        name: "{{ image_name }}"
        build:
          path: "{{ postgre_container }}"
        source: build
        state: present
    - name: Launch postgresql docker container
      docker_container:
        name: "{{ container_name }}"
        image: "{{ image_name }}"
        state: started
        ports:
          - "5432:5432"
        env:
          POSTGRES_PASSWORD: "Pp123456789"
        volumes:
          - /custom/mount:/var/lib/postgresql/data
      register: docker_info
- name: Nodejs Server configuration
  hosts: ansible_nodejs
  become: true
  gather_facts: No
  any_errors_fatal: true
  vars:
    nodejs_home: /home/ec2-user/ansible-servers/nodejs
    container_path: /home/ec2-user/nodejs
    container_name: enes_nodejs
    image_name: devenes/nodejs
  tasks:
    - name: create build directory
      file:
        path: "{{ container_path }}"
        state: directory
        owner: root
        group: root
        mode: "0755"
    # at this point do not forget change DB_HOST env variable for postgresql node
    - name: copy files to the nodejs node
      copy:
        src: /home/ec2-user/ansible-servers/todo-app-pern/server/
        dest: "{{ container_path }}"
    - name: copy the Dockerfile
      copy:
        src: /home/ec2-user/ansible-servers/nodejs/Dockerfile
        dest: "{{ container_path }}"
    - name: remove {{ container_name }} container and {{ image_name }} if exists
      shell: "docker ps -q --filter 'name={{ container_name }}' && docker stop {{ container_name }} && docker rm -fv {{ container_name }} && docker image rm -f {{ image_name }} || echo 'Not Found'"
    - name: build container image
      docker_image:
        name: "{{ image_name }}"
        build:
          path: "{{ container_path }}"
        source: build
        state: present
    - name: Launch postgresql docker container
      docker_container:
        name: "{{ container_name }}"
        image: "{{ image_name }}"
        state: started
        ports:
          - "5000:5000"
- name: React UI Server configuration
  hosts: ansible_react
  become: true
  gather_facts: No
  any_errors_fatal: true
  vars:
    react_home: /home/ec2-user/ansible-servers/react
    container_path: /home/ec2-user/react
    container_name: enes_react
    image_name: devenes/react
  tasks:
    - name: create build directory
      file:
        path: "{{ container_path }}"
        state: directory
        owner: root
        group: root
        mode: "0755"
    # at this point do not forget change DB_HOST env variable for postgresql node
    - name: copy files to the react node
      copy:
        src: /home/ec2-user/ansible-servers/todo-app-pern/client/
        dest: "{{ container_path }}"
    - name: copy the Dockerfile
      copy:
        src: /home/ec2-user/ansible-servers/react/Dockerfile
        dest: "{{ container_path }}"
    - name: remove {{ container_name }} container and {{ image_name }} image if exists
      shell: "docker ps -q --filter 'name={{ container_name }}' && docker stop {{ container_name }} && docker rm -fv {{ container_name }} && docker image rm -f {{ image_name }} || echo 'Not Found'"
    - name: build container image
      docker_image:
        name: "{{ image_name }}"
        build:
          path: "{{ container_path }}"
        source: build
        state: present
    - name: Launch react docker container
      docker_container:
        name: "{{ container_name }}"
        image: "{{ image_name }}"
        state: started
        ports:
          - "3000:3000"
```

- Execute it.

```bash
ansible-playbook docker_project.yaml
```
