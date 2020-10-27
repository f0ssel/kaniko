# Idea

Represent images and environments by templates in one or many github repositories.

```
.coder/
  images/
    enterprise-dev.yaml
    ubuntu.yaml
    python.yaml
  environments/
    team-a.yaml
    f0ssel-dev.yaml
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

Users will select environment templates to build environments from.

An environment build will have the following steps:
- Pull repo manually into a shared empty dir from init container
- Edit dockerfile to add our own layers for copying assets into the env at /tmp/coder
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
