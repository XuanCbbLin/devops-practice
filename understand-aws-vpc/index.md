# 瞭解 AWS VPC

## 什麼是 VPC、 CIDR、Subnet、Route Table、NAT Gateway、Internet Gateway

1. 什麼是 VPC (Virtual Private Cloud): 是雲端上的虛擬網路，對比地端網路。

2. 什麼是 CIDR (Classless Inter-Domain Routing): 一種 IP 位址範圍的表示方法（例如 10.0.0.0/16）。

3. 什麼是 Subnet: VPC 內部的網路區段，每個 subnet 對應一個 Availability Zone (AZ)，有自己的 CIDR block（必須是 VPC CIDR 的子集）。

4. 什麼是 Route Table: 定義網路流量的路由規則，決定不同目的地的流量要走哪個 gateway 或路徑。

5. 什麼是 NAT Gateway: 讓 private subnet 連到外面的網路。

6. 什麼是 Internet Gateway (IGW): 讓 public subnet 連到外面的網路。

### 架構圖

```
                       ┌─────────────────────────┐
                       │        Internet         │
                       └───────────┬─────────────┘
                                   │
                       ┌───────────▼─────────────┐
                       │   Internet Gateway      │
                       └───────────┬─────────────┘
                                   │
       ┌───────────────────────────┼───────────────────────────┐
       │           VPC (10.0.0.0/16)                           │
       │                           │                           │
       │  ┌────────────────────────┼────────────────────┐      │
       │  │  Public Subnet (10.0.1.0/24)                │      │
       │  │                        │                    │      │
       │  │  ┌──────────┐          │      ┌──────────┐  │      │
       │  │  │   EC2    │          │      │   NAT    │  │      │
       │  │  │Public IP │          │      │ Gateway  │  │      │
       │  │  └──────────┘          │      └─────┬────┘  │      │
       │  │                        │            │       │      │
       │  │  Route Table           │            │       │      │
       │  │  0.0.0.0/0 → IGW       │            │       │      │
       │  └────────────────────────┼────────────┼────── ┘      │
       │                           │            │              │
       │  ┌────────────────────────┼────────────▼──────┐       │
       │  │  Private Subnet (10.0.2.0/24)              │       │
       │  │                        │                   │       │
       │  │  ┌──────────┐          │                   │       │
       │  │  │   EC2    │          │                   │       │
       │  │  │PrivateIP │          │                   │       │
       │  │  └──────────┘          │                   │       │
       │  │                        │                   │       │
       │  │  Route Table           │                   │       │
       │  │  0.0.0.0/0 → NAT GW    │                   │       │
       │  └────────────────────────┼───────────────────┘       │
       │                           │                           │
       └───────────────────────────┼───────────────────────────┘
                                   │

路徑說明：
1. Public EC2 → Internet: 透過 Internet Gateway (IGW) 直接連線
2. Private EC2 → Internet: 透過 NAT Gateway → Internet Gateway
3. Internet → Public EC2: 透過 Internet Gateway (雙向)
4. Internet → Private EC2: 無法直接連線（僅單向對外）
```

## 嘗試手動操作，創建一個有兩個 subnet 的 vpc，並且分成 private 跟 public subnet

使用 nat gateway 確保 private subnet 可以存取 internet(google.com)

驗證：在 private subnet 內創建 ec2，並且嘗試在該 ec2 內去 curl google.com

### 手動建立 VPC

在 AWS console 的 VPC 建立自己的 VPC

#### 建立 VPC

1. 登入 AWS 管理主控台

2. 左側選單 → 點選「Your VPCs」→「Create VPC」

3. 選項：

    - Name tag: my-vpc
    - IPv4 CIDR block: 10.0.0.0/16

4. 按下「Create VPC」

#### 建立 Subnet

##### 建立 Public Subnets

1. 左側 → 點選「Subnets」→「Create subnet」
2. 選擇剛才建立的 VPC：my-vpc

3. 填入：
    - Subnet name: public-subnet
    - Availability Zone: us-east-1a
    - IPv4 CIDR block: 10.0.1.0/24

建立完成後，選擇該 subnet => 點 `Actions` => `Edit subnet settings`

開啟「Auto-assign IP settings」中 的 Enable auto-assign public IPv4 address

這樣 EC2 放進這個 subnet 就能自動拿 public IP。

##### 建立 Private Subnet

1. 再次建立 subnet：

    - Subnet name: private-subnet
    - Availability Zone: 同上 us-east-1a
    - IPv4 CIDR block: 10.0.2.0/24

2. 選擇剛才建立的 VPC：my-vpc
3. 不要開啟 auto-assign public IP。

#### 建立 Internet Gateway (IGW)

1. 左側選單 => 「Internet Gateways」=>「Create internet gateway」
2. Name: my-igw
3. 建立後選擇剛建立的 IGW 點 Actions => Attach to VPC
4. 選擇 my-vpc => Attach

#### 建立 NAT Gateway

NAT Gateway 會放在 public subnet 裡，讓 private subnet 能透過它上網。

1. 左側選單 => 「NAT Gateways」=>「Create NAT Gateway」

2. 設定：

    - Name: my-nat-gateway
    - Subnet: public-subnet
    - Elastic IP allocation: 點「Allocate Elastic IP」

3. 按下「Create NAT Gateway」

#### 設定 Route Tables

##### Public Route Table

1. 左側 => 「Route Tables」=> 找到與 my-vpc 關聯的 Route Table
2. 改名為：public-rt
3. 點「Routes」=>「Edit routes」=> 「Add route」

    - Destination: 0.0.0.0/0
    - Target: Internet Gateway (my-igw)

4. save

5. 點「Subnet associations」=>「Edit subnet associations」 選擇：public-subnet => Save

##### Private Route Table

1. 建立新 Route Table：

    - Name: private-rt
    - VPC: my-vpc

2. 點「Routes」=> 「Edit routes」新增：

    - Destination: 0.0.0.0/0
    - Target: NAT Gateway (my-nat-gateway)

3. 儲存
4. 點「Subnet associations」=>「Edit subnet associations」選擇：private-subnet => Save

#### 建立 EC2 進行測試

##### Public EC2

1. 前往 EC2 => 「Launch instance」

2. 設定：
    - Name: public-ec2
    - AMI: Amazon Linux 2
    - Instance type: t2.micro
    - Key pair: 你自己的 key 或是建立新的 key pair
    - Network settings:
        - VPC: my-vpc
        - Subnet: public-subnet
        - Auto-assign Public IP: Enable

##### 建立 Private EC2

1. 再次 Launch instance
    - Name: private-ec2
    - AMI: Amazon Linux 2
    - Instance type: t2.micro
    - Key pair: 你自己的 key 或是建立新的 key pair
    - Network settings:
        - VPC: my-vpc
        - Subnet: private-subnet
        - Auto-assign Public IP: Disable

#### 測試連線

##### 先將產生出來的 private key 複製到 public-ec2

因為要從 public-ec2 連到 private-ec2，需要 private-ec2 的 key。

`scp -i ~/xxxx/xxx.pem(要登入的 public ec2 的 key) ~/xxxx/xxx.pem(要複製的 private ec2 的 key) ec2-user@<xxx(public ec2 的位址)>:/home/ec2-user/`

##### 連線到 public-ec2

1. 先到終端機切換到有建立 key(xxx.pem) 的目錄
2. chmod 400 "xxx.pem"
3. ssh -i "xxx.pem" ec2-user@xxx.xx.xx.xxx(IP 位址)

##### 從 public-ec2 連到 private-ec2

在 public-ec2 裡，執行：

`ssh -i "xxx.pem(這是一開始複製到 public-ec2 的 private ec2 的 key)" ec2-user@<private-ec2 的 private IP 位址>`

##### curl 到 google

curl -I https://www.google.com 如果能成功看到回應代表可以從 private-ec2 連到外網。

### 使用 Terraform

#### 建立 [main.tf](./aws-vpc-tf/main.tf)

#### 執行 terraform

1. 初始化 terraform

```bash
terraform init
```

2. 執行 plan

```bash
terraform plan
```

3. 執行 apply

```bash
terraform apply
```

#### 檢查 到 AWS console 確認資源建立成功。

#### 進 public subnet 的 EC2 連到 private subnet 的 EC2 測試。

這步驟同上面手動建立 VPC 的[測試連線](#測試連線)步驟一樣。
