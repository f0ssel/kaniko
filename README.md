# Idea

Represent images and environments by templates in one or many github repositories.

In this design the FE UI will just allow selecting of repos/templates/branchs/commits, and all configuration will live in the template files. This will thin down the complexity of the FE dramatically and push customers into versioning and source controlling the config for the platform. 

```
.coder/
  images/
    enterprise-dev.yaml
    ubuntu.yaml
    python.yaml
  environments/
    team-a.yaml
    f0ssel-dev.yaml
  secrets/
    db.yaml
    f0ssel-ssh.yaml
```

## Build Images

On push images are build in kaniko. These are base images that all teams can use.

Users will reference images in environment templetes with git repo, image repo & tag where the tag could be branch or commit.

Users reference image repository credentials by name.

### Value Add
- CICD for customer developer environment images
- Flexible reference pattern for environment templates

### Example
```
name: f0ssel-dev
type: image
spec:
  context: ./dev
  dockerfile: Dockerfile
  image: f0ssel/dev
  credentials: dockerhub-creds
```

## Build Environments

Users will select environment templates to build environments from a UI on environment creation.

Edits to the env will just be pointing the env at a different template/branch.

An environment build will have the following steps:
- Pull repo manually into a shared empty dir from init container
- Edit dockerfile to add our own layers for copying assets from our own envbuilder image into the new image at /tmp/coder
- Edit dockerfile to add personalize steps as final layers
- Build new personalized environment image
- Push custom image to repo with build ID tag
- Submit a deployment using the custom image and tag

Environment templates can have a large api with few required fields to let devs really make the templates their own.

We'd show little opinion on organizing around sharing of images/templates and let teams organize how they'd like.

### Value Adds
- No need to rerun personalize steps if container restarts
- Root access via docker build during environment setup
- Lets users express complicated setups like multi-container and volumes
- Removes tons of UI in the product

### Risk
- This may be slow if we don't utilize caches well

### Example
```
name: f0ssel-enterprise
type: environment
provider: kubernetes
spec:
  - name: env
    primary: true
    // this references the image name above 
    github: f0ssel/kaniko
    image: f0ssel-dev
    tag: master
    credentials: dockerhub-creds
    cpu: 2
    memory: 4GB
    // These layers are added last in environment image build
    personalize:
      - "RUN echo test3 > test3.txt"
  - name: postgres
    image: postgres
    env:
      - name: PGDATABASE
        value: coder
```

## Image Iteration (future)

Since kaniko can take a tar via stdin users could iterate on image development inside a coder environment without git in the mix. 

Iteration steps:
- User makes changes in relevant repo
- User submits build with cli (`coder build image my-image-name`)
- We tar up the relative context and pass it into stdin of the pod we create
- We build and push the image with a preview tag
- We setup a preview environment for them to verify before they commit the changes

## Secrets (future)

If users upload an encryption key to the platform, we can provide a utility to allow them to check in secrets into the git repo securely. 

`coder secret create --from-file=my-file --from-literal=key,value`

This will create a file in the `.coder/secrets/` directory with the data for each kv pair / file encrypted. This lets users check in secrets into source control and reference them directly in the templates like so:

```
name: f0ssel-enterprise
type: environment
provider: kubernetes
spec:
  - name: env
    primary: true
    // this references the image name above 
    github: f0ssel/kaniko
    image: f0ssel-dev
    tag: master
    credentials: dockerhub-creds
    cpu: 2
    memory: 4GB
    // These layers are added last in environment image build
    personalize:
      - "RUN echo test3 > test3.txt"
    env:
      - name: PGPASSWORD
        value: 
          fromSecret: 
            name: db.yaml
            key: password
```

We no longer have to deal with storing the secrets securely on our end by just providing the user with a convient KMS service tied into the platform. Dev secrets are generally handled different from production secrets so this model that favors convience over raw security is probably ideal for most customers. 
