// Copyright Project Harbor Authors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//    http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

package models

import (
	"context"
	"fmt"
	"time"

	"github.com/astaxie/beego/orm"
	"github.com/goharbor/harbor/src/pkg/signature/notary/model"
	"github.com/lib/pq"
	"github.com/theupdateframework/notary/tuf/data"
)

// RepoTable is the table name for repository
const RepoTable = "repository"

// TODO move the model into pkg/repository

// RepoRecord holds the record of an repository in DB, all the infors are from the registry notification event.
type RepoRecord struct {
	RepositoryID int64     `orm:"pk;auto;column(repository_id)" json:"repository_id"`
	Name         string    `orm:"column(name)" json:"name"`
	ProjectID    int64     `orm:"column(project_id)"  json:"project_id"`
	Description  string    `orm:"column(description)" json:"description"`
	PullCount    int64     `orm:"column(pull_count)" json:"pull_count"`
	StarCount    int64     `orm:"column(star_count)" json:"star_count"`
	CreationTime time.Time `orm:"column(creation_time);auto_now_add" json:"creation_time" sort:"default:desc"`
	UpdateTime   time.Time `orm:"column(update_time);auto_now" json:"update_time"`
}

// FilterByBlobDigest filters the repositories by the blob digest
func (r *RepoRecord) FilterByBlobDigest(ctx context.Context, qs orm.QuerySeter, key string, value interface{}) orm.QuerySeter {
	digest, ok := value.(string)
	if !ok || len(digest) == 0 {
		return qs
	}

	sql := fmt.Sprintf(`select distinct(a.repository_id)
				from artifact as a
				join artifact_blob as ab
				on a.digest = ab.digest_af
				where ab.digest_blob = %s`, pq.QuoteLiteral(digest))
	return qs.FilterRaw("repository_id", fmt.Sprintf("in (%s)", sql))
}

// TableName is required by by beego orm to map RepoRecord to table repository
func (r *RepoRecord) TableName() string {
	return RepoTable
}

// RepositoryQuery : query parameters for repository
type RepositoryQuery struct {
	Name        string
	ProjectIDs  []int64
	ProjectName string
	LabelID     int64
	Pagination
	Sorting
}

// TagResp holds the information of one image tag
type TagResp struct {
	TagDetail
	Signature    *model.Target          `json:"signature"`
	ScanOverview map[string]interface{} `json:"scan_overview,omitempty"`
	Labels       []*Label               `json:"labels"`
	PushTime     time.Time              `json:"push_time"`
	PullTime     time.Time              `json:"pull_time"`
}

// TagDetail ...
type TagDetail struct {
	Digest        string    `json:"digest"`
	Name          string    `json:"name"`
	Size          int64     `json:"size"`
	Architecture  string    `json:"architecture"`
	OS            string    `json:"os"`
	OSVersion     string    `json:"os.version"`
	DockerVersion string    `json:"docker_version"`
	Author        string    `json:"author"`
	Created       time.Time `json:"created"`
	Config        *TagCfg   `json:"config"`
	Immutable     bool      `json:"immutable"`
}

// TagCfg ...
type TagCfg struct {
	Labels map[string]string `json:"labels"`
}

// Signature ...
type Signature struct {
	Tag    string      `json:"tag"`
	Hashes data.Hashes `json:"hashes"`
}
