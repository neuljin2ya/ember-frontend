package com.ember.ember.global.system.domain;

import com.ember.ember.global.jpa.entity.BaseEntity;
import jakarta.persistence.*;
import lombok.*;

@Entity
@Table(name = "app_versions")
@Getter
@NoArgsConstructor(access = AccessLevel.PROTECTED)
public class AppVersion extends BaseEntity {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @Column(nullable = false, unique = true, length = 5)
    private String platform;

    @Column(name = "min_version", nullable = false, length = 20)
    private String minVersion;

    @Column(name = "recommended_version", nullable = false, length = 20)
    private String recommendedVersion;

    @Column(name = "store_url", nullable = false, length = 500)
    private String storeUrl;
}
